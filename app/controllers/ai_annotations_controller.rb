class AiAnnotationsController < ApplicationController
  include TokenLimitable

  def new
    @new_ai_annotation = AiAnnotation.new
  end

  def create
    text = ai_annotation_params[:text]
    prompt = ai_annotation_params[:prompt]
    @new_ai_annotation = AiAnnotation.prepare_with(text, prompt)

    ai_annotation = @new_ai_annotation.annotate!
    increment_token_usage(@new_ai_annotation.token_used)

    redirect_to "/ai_annotations/#{ai_annotation.uuid}"
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."
    render :new, status: :unprocessable_entity
  end

  def edit
    @ai_annotation = AiAnnotation.find_by!(uuid: params[:uuid])
    @content_json = @ai_annotation.content_as_json.to_json
  end

  def update
    @ai_annotation = AiAnnotation.find_by(uuid: params[:id])
    @ai_annotation.text_in_json = @ai_annotation.content
    @ai_annotation.content_in_json = ai_annotation_params[:content]
    @ai_annotation.prompt = ai_annotation_params[:prompt]

    ai_annotation = @ai_annotation.annotate!
    increment_token_usage(@ai_annotation.token_used)

    redirect_to "/ai_annotations/#{ai_annotation.uuid}"
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."
    render :edit, status: :unprocessable_entity
  end

  def content_as_json
    SimpleInlineTextAnnotation.parse(@ai_annotation.text)
  end

  private

  def ai_annotation_params
    params.require(:ai_annotation).permit(:text, :prompt, :content)
  end
end
