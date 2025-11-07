class AiAnnotationsController < ApplicationController
  include TokenLimitable
  before_action :authenticate_user!

  def index
    @ai_annotations = current_user ? AiAnnotation.where(user: current_user) : []
  end

  def show
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    redirect_to root_path unless @ai_annotation
  end

  def new
    @new_ai_annotation = AiAnnotation.new
    @jwt_token = current_user&.jwt_token
    @history = AiAnnotation.order(created_at: :desc).limit(10)
  end

  def create
    text = ai_annotation_params[:text]
    prompt = ai_annotation_params[:prompt]
    @new_ai_annotation = AiAnnotation.prepare_with(text, prompt)
    @new_ai_annotation.user = current_user if current_user

    ai_annotation = @new_ai_annotation.annotate!
    increment_token_usage(@new_ai_annotation.token_used)

    redirect_to "/ai_annotations/#{ai_annotation.uuid}"
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."
    render :new, status: :unprocessable_entity
  end

  def edit
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    @jwt_token = current_user&.jwt_token
    @history = AiAnnotation.order(created_at: :desc).limit(10)
    redirect_to root_path unless @ai_annotation
  end

  def update
    @ai_annotation = AiAnnotation.find_by(uuid: params[:uuid])
    @history = AiAnnotation.order(created_at: :desc).limit(10)
    @ai_annotation.annotation = JSON.parse(ai_annotation_params[:content])
    @ai_annotation.prompt = ai_annotation_params[:prompt]

    ai_annotation = @ai_annotation.annotate!
    increment_token_usage(@ai_annotation.token_used)
    redirect_to "/ai_annotations/#{ai_annotation.uuid}"
  rescue SimpleInlineTextAnnotation::RelationWithoutDenotationError => e
    # Error that may occur in SimpleInlineTextAnnotation when the LLM response is invalid
    Rails.logger.error "#{e.class}: #{e.message}"
    flash.now[:alert] = "Invalid response from AI. Please retry."
    @ai_annotation.reload
    render :edit, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Error: #{e.message}"
    flash.now[:alert] = "Unexpected error occurred while generating AI annotation."
    render :edit, status: :unprocessable_entity
  end

  private

  def ai_annotation_params
    params.require(:ai_annotation).permit(:text, :prompt, :content)
  end
end
