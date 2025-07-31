class AiAnnotation < ApplicationRecord
  attr_accessor :annotation, :text, :token_used

  before_create :clean_old_annotations
  before_create :set_uuid

  scope :old, -> { where("created_at < ?", 1.day.ago) }

  def self.prepare_with(text, prompt)
    instance = new
    instance.text = text
    instance.prompt = prompt
    instance
  end

  def annotate!(force: false)
    if @annotation.dig("selectedText", "status") == "selected"
      # Get selected range from the annotation
      begin_offset = @annotation.dig("selectedText", "begin").to_i
      end_offset = @annotation.dig("selectedText", "end").to_i
      result, tokens_used = selected_window @annotation, begin_offset, end_offset
    else
      result, tokens_used = sliding_window @annotation
    end

    self.token_used = tokens_used
    result = JSON.generate(result)

    ai_annotation = AiAnnotation.create!(prompt: prompt, content: result)
    # Return nil to show the warning dialog
    return nil if result.nil? || tokens_used.nil?

    ai_annotation
  end

  def text=(annotation)
    @text = annotation
    @annotation = SimpleInlineTextAnnotation.parse(annotation)
  end

  private

  # Delete old annotations
  def clean_old_annotations
    AiAnnotation.old.destroy_all
  end

  private
  # Set a new UUID
  def set_uuid
    self.uuid = SecureRandom.uuid
  end

  # Annotates the part specified by the user.
  def selected_window(annotation_json, begin_offset, end_offset)
    slicer = AnnotationSlicer.new(annotation_json)
    selected_annotation = slicer.annotation_in(begin_offset..end_offset)
    annotation_text = SimpleInlineTextAnnotation.generate(selected_annotation)

    user_content = "#{annotation_text}\n\nPrompt:\n#{prompt}"

    tokens_used, result = OpenAiAnnotator.new.call(user_content)
    result_as_json = SimpleInlineTextAnnotation.parse(result)

    merged_result = AnnotationMerger.new([
                                           slicer.annotation_in(0...begin_offset),
                                           result_as_json,
                                           slicer.annotation_in(end_offset..annotation_json["text"].length)
                                         ]).merged

    [ merged_result, tokens_used ]
  end

  def sliding_window(annotation_json, force: false)
    begin
      chunks = TokenChunk.from annotation_json, window_size: 20, strict_mode: !force
    rescue Exceptions::RelationOutOfRangeError => e
      if force
        # If force mode, re-split with strict_mode: false
        chunks = TokenChunk.from annotation_json, window_size: 20, strict_mode: false
      else
        # The selected choice (button value) should be obtained in the controller via params[:button]
        # Cannot be obtained here, so interrupt processing
        return
      end
    end

    result = chunks.each_with_object({ token_used: 0, chunk_results: [] })
                   .with_index do |(chunk, results), index|
      annotation_text = SimpleInlineTextAnnotation.generate(chunk)

      user_content = "#{annotation_text}\n\nPrompt:\n#{prompt}"
      user_content += "\n\n(This is part #{index + 1}. Please annotate this part only.)" if chunks.size > 1

      adding_tokens_sum, chunk_result = OpenAiAnnotator.new.call(user_content)
      results[:token_used] += adding_tokens_sum

      # Remove backslashes from OpenAI response
      chunk_result = chunk_result.gsub("\\", "")

      begin
        adding_result_as_json = SimpleInlineTextAnnotation.parse(chunk_result)
        results[:chunk_results] << adding_result_as_json
      rescue => e
        # Log the error but continue processing other chunks
        Rails.logger.error "Error parsing chunk result: #{e.message}"
      end
    end

    [
      AnnotationMerger.new(result[:chunk_results]).merged,
      result[:token_used]
    ]
  end

  # Delete old annotations
  def clean_old_annotations
    AiAnnotation.old.destroy_all
  end

  # Set a new UUID
  def set_uuid
    self.uuid = SecureRandom.uuid
  end
end
