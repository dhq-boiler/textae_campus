require "test_helper"

class AiAnnotationTest < ActiveSupport::TestCase
  test "should delete old annotation when creating new instance" do
    AiAnnotation.create!(content: "aaa", created_at: 2.days.ago)
    AiAnnotation.create!(content: "bbb")

    assert AiAnnotation.exists?(content: "bbb")
    assert_not AiAnnotation.exists?(content: "aaa")
  end
end
