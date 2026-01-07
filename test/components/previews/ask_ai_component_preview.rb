class AskAiComponentPreview < ViewComponent::Preview
  # @param variant select {{ DS::AskAi::VARIANTS }}
  def default(variant: "button")
    render DS::AskAi.new(variant: variant)
  end

  # Pill variant - more compact button style
  def pill
    render DS::AskAi.new(variant: :pill)
  end

  # With custom placeholder text
  def custom_placeholder
    render DS::AskAi.new(placeholder: "How can I help you today?")
  end

  # With page context for contextual suggestions
  def with_context
    render DS::AskAi.new(context: :transactions, metadata: { account_id: 1 })
  end
end
