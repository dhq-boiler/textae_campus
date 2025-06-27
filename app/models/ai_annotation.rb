class AiAnnotation < ApplicationRecord
  attr_accessor :text, :prompt, :token_used

  FORMAT_SPECIFICATION = <<~EOS
    Annotate the text according to the prompt with using the following syntax:

    ## Annotation Format
    - An annotation consists of two consecutive square bracket pairs:
      - First: annotated text
      - Second: label
    - Example: [Annotated Text][Label]

    ## Label Definition (Optional)
    - Labels can be defined as `[Label]: URL`.

    ## Escaping Metacharacters
    - To prevent misinterpretation, escape the first `[` if it naturally occurs.
    - Example: \[Part of][Original Text]

    ## Handling Unknown Prompts
    - If could not understand prompt, return the input text unchanged.

    Output the original text with annotations.
  EOS

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
    # To reduce the risk of API key leakage, API error logging is disabled by default.
    # If you need to check the error details, enable logging by add argument `log_errors: true` like: OpenAI::Client.new(log_errors: true)
    client = OpenAI::Client.new
    response = client.chat(
      parameters: {
        model: "gpt-4o",
        messages: [
          { role: "system", content: FORMAT_SPECIFICATION },
          { role: "user", content: "#{@text}\n\nPrompt:\n#{@prompt}" }
        ]
      }
    )

    self.token_used = response.dig("usage", "total_tokens").to_i
    result = response.dig("choices", 0, "message", "content")
    AiAnnotation.create!(content: result)
  end

  def text_in_json=(annotation_json)
    self.text = convert_to_indifferent_access(annotation_json)
  end

  # contentをJSON形式で取得する
  def content_as_json
    # contentがJSON文字列かどうかをチェック
    begin
      parsed = JSON.parse(content)
      # textキーとdenotationsキーを持つハッシュの場合、既にJSON構造と判断
      if parsed.is_a?(Hash) && parsed.key?('text') && parsed.key?('denotations')
        return parsed
      end
    rescue JSON::ParserError
      # JSONとして解析できない場合は通常のパース処理を続行
    end

    # 通常のパース処理（シンプルインラインテキストフォーマット→JSON）
    SimpleInlineTextAnnotation.parse(content)
  end

  # JSON形式の内容からcontent属性にシンプルインラインテキストフォーマットを設定
  def content_in_json=(annotation_json)
    annotation_json = SimpleInlineTextAnnotation.parse(convert_to_indifferent_access(annotation_json))
    annotation_json = convert_to_indifferent_access(annotation_json)
    self.content = SimpleInlineTextAnnotation.generate(annotation_json)
  end

  private

  def clean_old_annotations
    AiAnnotation.old.destroy_all
  end

  def set_uuid
    self.uuid = SecureRandom.uuid
  end

  # Convert symbol keys to string keys in arrays so they can be accessed with array["key"] syntax
  # This conversion is applied recursively to nested elements
  def convert_to_indifferent_access(obj)
    case obj
    when Hash
      obj.with_indifferent_access.transform_values { |v| convert_to_indifferent_access(v) }
    when Array
      obj.map { |item| convert_to_indifferent_access(item) }
    else
      obj
    end
  end
end
