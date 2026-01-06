module AiPromptsHelper
  PAGE_CONTEXT_MAPPING = {
    dashboard: PageContext::DashboardContext,
    transactions: PageContext::TransactionsContext,
    accounts: PageContext::AccountsContext,
    budgets: PageContext::BudgetsContext,
    reports: PageContext::ReportsContext,
    investments: PageContext::InvestmentsContext
  }.freeze

  PAGE_CONTEXT_ICONS = {
    dashboard: "pie-chart",
    transactions: "credit-card",
    accounts: "landmark",
    budgets: "map",
    reports: "chart-bar",
    investments: "chart-candlestick"
  }.freeze

  # Main entry point - returns contextual prompts for the chat
  # First uses page-specific prompts, then supplements with general smart suggestions
  def contextual_chat_prompts(family:, page_context_key:, metadata: {}, count: 3)
    # Get page-specific prompts
    page_prompts = page_context_prompts(family, page_context_key, metadata)

    # If we have enough page prompts, use them
    return page_prompts.first(count) if page_prompts.size >= count

    # Otherwise, supplement with general smart suggestions
    remaining = count - page_prompts.size
    general_prompts = smart_chat_suggestions(family).first(remaining)

    (page_prompts + general_prompts).first(count)
  end

  # Get prompts specific to the current page context
  def page_context_prompts(family, page_context_key, metadata = {})
    return [] unless page_context_key.present?

    context_class = page_context_class(page_context_key)
    return [] unless context_class

    context = context_class.new(
      family: family,
      user: Current.user,
      metadata: metadata
    )
    return [] unless context.available?

    context.prompts
  rescue => e
    Rails.logger.error("Page context prompts failed for #{page_context_key}: #{e.message}")
    []
  end

  # Map page context key to class
  def page_context_class(key)
    PAGE_CONTEXT_MAPPING[key.to_sym]
  end

  # Get icon for a page context
  def page_context_icon(key)
    PAGE_CONTEXT_ICONS[key.to_sym] || "sparkles"
  end

  # Get human-readable name for page context
  def page_context_name(key)
    I18n.t("ai_prompts.page_names.#{key}", default: key.to_s.titleize)
  end

  # Determine current page context key from controller
  def current_page_context_key
    case controller_name
    when "pages" then :dashboard
    when "transactions", "entries" then :transactions
    when "accounts" then :accounts
    when "budgets" then :budgets
    when "reports" then :reports
    when "investments", "holdings" then :investments
    else nil
    end
  end

  # Build metadata hash for current page context
  def current_page_metadata
    case controller_name
    when "transactions", "entries"
      {
        has_filters: params[:q].present?,
        search_params: params[:q]
      }
    when "accounts"
      {
        account_id: params[:id]
      }
    else
      {}
    end
  end
end
