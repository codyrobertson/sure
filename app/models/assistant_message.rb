class AssistantMessage < Message
  validates :ai_model, presence: true

  def role
    "assistant"
  end

  def append_text!(text)
    self.content += text
    save!
  end

  # Returns suggested options from the suggest_options tool call, if any
  def suggested_options
    suggest_call = tool_calls.find { |tc| tc.function_name == "suggest_options" }
    return [] unless suggest_call

    args = suggest_call.function_arguments
    return [] unless args.is_a?(Hash) && args["options"].is_a?(Array)

    args["options"].map do |opt|
      {
        label: opt["label"],
        prompt: opt["prompt"]
      }
    end
  end

  def has_suggestions?
    suggested_options.any?
  end

  CHART_FUNCTION_NAMES = %w[
    generate_time_series_chart
    generate_account_balance_chart
    generate_donut_chart
    generate_sankey_chart
  ].freeze

  # Returns chart data from any chart function tool call
  def chart_data
    chart_call = tool_calls.find { |tc| CHART_FUNCTION_NAMES.include?(tc.function_name) }
    return nil unless chart_call

    result = chart_call.function_result
    return nil unless result.is_a?(Hash) && result["chart_type"].present?

    result.with_indifferent_access
  end

  def has_chart?
    chart_data.present?
  end

  # Returns web search results from the web_search tool call, if any
  def web_search_results
    search_call = tool_calls.find { |tc| tc.function_name == "web_search" }
    return nil unless search_call

    result = search_call.function_result
    return nil unless result.is_a?(Hash) && result["results"].present?

    result.with_indifferent_access
  end

  def has_web_search_results?
    web_search_results.present? && web_search_results[:results].any?
  end
end
