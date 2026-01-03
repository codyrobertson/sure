class Assistant::Function::SuggestOptions < Assistant::Function
  class << self
    def name
      "suggest_options"
    end

    def description
      "Present clickable options to the user when you need them to choose between specific paths. " \
      "Use this ONLY when different options would lead to meaningfully different analyses or actions. " \
      "Do NOT use this for simple yes/no questions or when you should just fetch data yourself."
    end
  end

  def params_schema
    build_schema(
      properties: {
        options: {
          type: "array",
          description: "2-4 concise options for the user to choose from. Each should be a short action phrase (e.g., 'Show balances', 'Avalanche strategy', 'Recent payments')",
          items: {
            type: "object",
            properties: {
              label: {
                type: "string",
                description: "Short display text (2-4 words)"
              },
              prompt: {
                type: "string",
                description: "The full prompt to send when clicked (can be more detailed than label)"
              }
            },
            required: %w[label prompt],
            additionalProperties: false
          },
          minItems: 2,
          maxItems: 4
        }
      },
      required: %w[options]
    )
  end

  def call(params = {})
    # This function doesn't actually do anything - it just stores the options
    # in the tool_call record so the UI can render them as clickable badges
    options = params["options"] || []

    {
      success: true,
      options_count: options.length,
      message: "Options presented to user"
    }
  end
end
