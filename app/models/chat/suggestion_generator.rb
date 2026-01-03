class Chat::SuggestionGenerator
  CACHE_TTL = 24.hours
  SUGGESTION_COUNT = 10

  def initialize(family)
    @family = family
  end

  def suggestions
    cached = read_cache
    return cached if cached.present?

    generated = generate_suggestions
    write_cache(generated)
    generated
  end

  def refresh!
    clear_cache
    suggestions
  end

  private

  attr_reader :family

  def cache_key
    "chat_suggestions:#{family.id}"
  end

  def read_cache
    cached = Rails.cache.read(cache_key)
    return nil unless cached

    JSON.parse(cached, symbolize_names: true)
  rescue JSON::ParserError
    nil
  end

  def write_cache(suggestions)
    Rails.cache.write(cache_key, suggestions.to_json, expires_in: CACHE_TTL)
  end

  def clear_cache
    Rails.cache.delete(cache_key)
  end

  def generate_suggestions
    # Build a financial summary for the AI
    summary = build_financial_summary

    chat_history = build_chat_history_summary

    prompt = <<~PROMPT
      Based on this user's financial data and recent chat history, generate #{SUGGESTION_COUNT} personalized questions they might want to ask a financial assistant.

      Make questions specific to THEIR data - use actual category names, account names, merchant names, and amounts where relevant.

      #{summary}

      #{chat_history}

      Return ONLY a JSON array of objects with "icon" and "text" keys. Use these Lucide icon names:
      trending-down, trending-up, pie-chart, chart-line, credit-card, piggy-bank, wallet,
      landmark, store, repeat, calendar, search, tag, zap, sparkles, lightbulb, target,
      calculator, bell, scale, chart-candlestick

      Example format:
      [{"icon": "trending-down", "text": "Why did I spend $500 on Dining this month?"}]

      Make questions conversational and specific. Include a mix of:
      - Spending analysis questions (with real category names and amounts)
      - Account-specific questions (with real account names)
      - Trend/comparison questions
      - Action-oriented questions (categorize, set up rules, etc.)
      - Follow-up questions based on recent chat topics (if any chat history)
    PROMPT

    response = call_ai(prompt)
    parse_response(response)
  rescue => e
    Rails.logger.error("Chat suggestion generation failed: #{e.message}")
    fallback_suggestions
  end

  def build_financial_summary
    period = Period.last_30_days
    accounts = family.accounts.visible
    income_statement = family.income_statement

    summary = []

    # Account summary
    summary << "ACCOUNTS:"
    accounts.group_by(&:accountable_type).each do |type, accts|
      accts.each do |account|
        summary << "- #{account.name} (#{type}): #{account.balance&.format || 'N/A'}"
      end
    end

    # Top spending categories
    expense_totals = income_statement.expense_totals(period: period)
    top_expenses = expense_totals.category_totals
      .reject { |ct| ct.total.zero? }
      .sort_by { |ct| -ct.total }
      .first(10)

    if top_expenses.any?
      summary << "\nTOP SPENDING THIS MONTH:"
      top_expenses.each do |expense|
        summary << "- #{expense.category.name}: #{expense.total.format}"
      end
    end

    # Income
    income_totals = income_statement.income_totals(period: period)
    if income_totals.total.positive?
      summary << "\nINCOME THIS MONTH: #{income_totals.total.format}"
    end

    # Top merchants
    top_merchants = family.transactions
      .joins(:entry, :merchant)
      .where(entries: { date: period.date_range })
      .group("merchants.name")
      .sum("entries.amount")
      .sort_by { |_, v| -v.abs }
      .first(5)

    if top_merchants.any?
      summary << "\nTOP MERCHANTS:"
      top_merchants.each do |name, amount|
        summary << "- #{name}: #{Money.new(amount * 100, family.currency).format}"
      end
    end

    # Uncategorized count
    uncategorized = family.transactions
      .joins(:entry)
      .where(category_id: nil)
      .where(entries: { date: period.date_range })
      .count

    if uncategorized > 0
      summary << "\nUNCATEGORIZED TRANSACTIONS: #{uncategorized}"
    end

    summary.join("\n")
  end

  def build_chat_history_summary
    # Get recent chats from the past week
    recent_chats = family.chats
      .where("created_at > ?", 7.days.ago)
      .order(created_at: :desc)
      .limit(10)

    return "" if recent_chats.empty?

    summary = ["\nRECENT CHAT TOPICS:"]

    recent_chats.each do |chat|
      # Get the first user message from each chat as the topic
      first_message = chat.messages.where(type: "UserMessage").order(:created_at).first
      next unless first_message

      summary << "- #{first_message.content.truncate(100)}"
    end

    summary.join("\n")
  end

  def ai_client
    @ai_client ||= OpenAI::Client.new(access_token: Setting.openai_api_key)
  end

  def call_ai(prompt)
    response = ai_client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: "You are a helpful financial assistant. Respond only with valid JSON." },
          { role: "user", content: prompt }
        ],
        temperature: 0.8
      }
    )

    response.dig("choices", 0, "message", "content")
  end

  def parse_response(response)
    # Extract JSON from response
    json_match = response.match(/\[[\s\S]*\]/)
    return fallback_suggestions unless json_match

    parsed = JSON.parse(json_match[0], symbolize_names: true)

    # Validate structure
    parsed.select do |item|
      item.is_a?(Hash) && item[:icon].present? && item[:text].present?
    end.first(SUGGESTION_COUNT)
  rescue JSON::ParserError
    fallback_suggestions
  end

  def fallback_suggestions
    [
      { icon: "pie-chart", text: "Show my spending breakdown for this month" },
      { icon: "trending-up", text: "How is my net worth trending?" },
      { icon: "repeat", text: "What are my recurring expenses?" },
      { icon: "search", text: "Find my largest transactions this month" },
      { icon: "tag", text: "Help me categorize my transactions" },
      { icon: "sparkles", text: "Give me a financial health checkup" },
      { icon: "lightbulb", text: "Where can I cut spending?" },
      { icon: "target", text: "Help me create a savings goal" },
      { icon: "calendar", text: "Compare this month to last month" },
      { icon: "zap", text: "Set up auto-categorization rules" }
    ]
  end
end
