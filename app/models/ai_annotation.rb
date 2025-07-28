class AiAnnotation < ApplicationRecord
  attr_accessor :text, :prompt, :token_used

  before_create :clean_old_annotations
  before_create :set_uuid

  scope :old, -> { where("created_at < ?", 1.day.ago) }

  def self.prepare_with(text, prompt)
    instance = new
    instance.text = text
    instance.prompt = prompt
    instance
  end

  def annotate!
    openai_annotator = OpenAiAnnotator.new

    # SimpleInlineTextAnnotationはキーをシンボルで返します
    parameter = SimpleInlineTextAnnotation.parse(@text).deep_stringify_keys

    chunks = TokenChunk.new.from parameter, window_size: 30

    total_tokens_used, combined_result = chunks.each_with_index.reduce([ 0, "" ]) do |(tokens_sum, result), (chunk, index)|
      simple_inline_text = SimpleInlineTextAnnotation.generate(chunk)
      user_content = "#{simple_inline_text}\n\nPrompt:\n#{@prompt}"
      user_content += "\n\n(This is part #{index + 1}. Please annotate this part only.)" if chunks.take(2).size > 1
      adding_tokens_sum, adding_result = openai_annotator.call(user_content)
      # SimpleInlineTextAnnotationはキーをシンボルで返します
      adding_result_as_json = SimpleInlineTextAnnotation.parse(adding_result).deep_stringify_keys
      [ tokens_sum + adding_tokens_sum, AnnotationMerger.new([result, adding_result_as_json].compact.reject(&:empty?)).merged ]
    end

    self.token_used = total_tokens_used
    result = JSON.generate(combined_result)
    AiAnnotation.create!(content: result)
  end

  def text_json=(annotation_json)
    self.text = SimpleInlineTextAnnotation.generate(annotation_json)
  end

  private

  def clean_old_annotations
    AiAnnotation.old.destroy_all
  end

  def set_uuid
    self.uuid = SecureRandom.uuid
  end
end
