class Assistant
  include Provided, Configurable, Broadcastable

  attr_reader :chat, :instructions

  class << self
    def for_chat(chat)
      config = config_for(chat)
      new(chat, instructions: config[:instructions], functions: config[:functions])
    end
  end

  def initialize(chat, instructions: nil, functions: [])
    @chat = chat
    @instructions = instructions
    @functions = functions
  end

  def respond_to(message)
    assistant_message = AssistantMessage.new(
      chat: chat,
      content: "",
      ai_model: message.ai_model
    )

    llm_provider = get_model_provider(message.ai_model)

    unless llm_provider
      error_message = build_no_provider_error_message(message.ai_model)
      raise StandardError, error_message
    end

    responder = Assistant::Responder.new(
      message: message,
      instructions: instructions,
      function_tool_caller: function_tool_caller,
      llm: llm_provider
    )

    latest_response_id = chat.latest_assistant_response_id

    responder.on(:output_text) do |text|
      if assistant_message.content.blank?
        stop_thinking
        assistant_message.append_text!(text)
      else
        assistant_message.append_text!(text)
      end
    end

    # Show thinking message BEFORE functions start executing
    responder.on(:functions_starting) do |data|
      Rails.logger.info("Assistant received functions_starting - names: #{data[:function_names].inspect}")
      thinking_message = build_thinking_message_from_names(data[:function_names])
      Rails.logger.info("Assistant thinking message: #{thinking_message}")
      update_thinking(thinking_message)
    end

    responder.on(:response) do |data|
      if data[:function_tool_calls].present?
        assistant_message.tool_calls = data[:function_tool_calls]
        # Don't update latest_response_id here - the intermediate response with function calls
        # expects function output. Wait for the final response after function execution.
      elsif data[:has_pending_functions]
        # AI tried to make another function call but we don't support recursive calls
        # Don't save this response ID as it expects function output we won't provide
        Rails.logger.warn("Not saving response ID due to unsupported recursive function call")
        # Still need to stop thinking and finalize the message
        stop_thinking
        assistant_message.save! if assistant_message.content.present?
      else
        # Only save the final response ID (after function execution completes)
        chat.update_latest_response!(data[:id])
      end
    end

    responder.respond(previous_response_id: latest_response_id)

    # Ensure thinking indicator is cleared when response completes
    stop_thinking
  rescue => e
    stop_thinking
    chat.add_error(e)
  end

  private
    attr_reader :functions

    FUNCTION_MESSAGES = {
      "get_transactions" => "Searching transactions...",
      "get_accounts" => "Looking up your accounts...",
      "get_balance_sheet" => "Calculating net worth...",
      "get_income_statement" => "Analyzing income & expenses...",
      "categorize_transactions" => "Categorizing transactions...",
      "tag_transactions" => "Tagging transactions...",
      "update_transactions" => "Updating transactions...",
      "create_category" => "Creating category...",
      "update_category" => "Updating category...",
      "delete_category" => "Deleting category...",
      "create_tag" => "Creating tag...",
      "create_rule" => "Setting up automation rule...",
      "generate_time_series_chart" => "Generating time series chart...",
      "generate_donut_chart" => "Generating donut chart...",
      "generate_sankey_chart" => "Generating cash flow chart...",
      "generate_account_balance_chart" => "Generating account balance chart...",
      "web_search" => "Searching the web..."
    }.freeze

    def build_thinking_message(tool_calls)
      return "Analyzing your data..." if tool_calls.blank?
      function_names = tool_calls.map(&:function_name).uniq
      build_thinking_message_from_names(function_names)
    end

    def build_thinking_message_from_names(function_names)
      return "Analyzing your data..." if function_names.blank?

      # Build contextual messages
      messages = function_names.map do |name|
        FUNCTION_MESSAGES[name] || "Processing #{name.humanize.downcase}..."
      end

      messages.join(" ")
    end

    def function_tool_caller
      function_instances = functions.map do |fn|
        fn.new(chat.user)
      end

      @function_tool_caller ||= begin
        caller = FunctionToolCaller.new(function_instances)
        caller.on_progress { |msg| update_thinking(msg) }
        caller
      end
    end

    def build_no_provider_error_message(requested_model)
      available_providers = registry.providers

      if available_providers.empty?
        "No LLM provider configured that supports model '#{requested_model}'. " \
        "Please configure an LLM provider (e.g., OpenAI) in settings."
      else
        provider_details = available_providers.map do |provider|
          "  - #{provider.provider_name}: #{provider.supported_models_description}"
        end.join("\n")

        "No LLM provider configured that supports model '#{requested_model}'.\n\n" \
        "Available providers:\n#{provider_details}\n\n" \
        "Please either:\n" \
        "  1. Use a supported model from the list above, or\n" \
        "  2. Configure a provider that supports '#{requested_model}' in settings."
      end
    end
end
