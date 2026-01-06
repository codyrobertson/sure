require "test_helper"

class AiPromptsHelperTest < ActionView::TestCase
  include AiPromptsHelper
  include ChatsHelper

  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
    Current.user = @user
  end

  teardown do
    Current.user = nil
  end

  test "contextual_chat_prompts returns prompts for valid page context" do
    prompts = contextual_chat_prompts(
      family: @family,
      page_context_key: :transactions,
      count: 3
    )

    assert prompts.is_a?(Array)
    assert prompts.length <= 3
  end

  test "contextual_chat_prompts falls back to smart suggestions for nil page context" do
    prompts = contextual_chat_prompts(
      family: @family,
      page_context_key: nil,
      count: 3
    )

    assert prompts.is_a?(Array)
  end

  test "page_context_class returns correct class for each key" do
    assert_equal PageContext::DashboardContext, page_context_class(:dashboard)
    assert_equal PageContext::TransactionsContext, page_context_class(:transactions)
    assert_equal PageContext::AccountsContext, page_context_class(:accounts)
    assert_equal PageContext::BudgetsContext, page_context_class(:budgets)
    assert_equal PageContext::ReportsContext, page_context_class(:reports)
    assert_equal PageContext::InvestmentsContext, page_context_class(:investments)
  end

  test "page_context_class returns nil for unknown key" do
    assert_nil page_context_class(:unknown)
  end

  test "page_context_icon returns correct icon for each key" do
    assert_equal "pie-chart", page_context_icon(:dashboard)
    assert_equal "credit-card", page_context_icon(:transactions)
    assert_equal "landmark", page_context_icon(:accounts)
    assert_equal "map", page_context_icon(:budgets)
    assert_equal "chart-bar", page_context_icon(:reports)
    assert_equal "chart-candlestick", page_context_icon(:investments)
  end

  test "page_context_icon returns sparkles for unknown key" do
    assert_equal "sparkles", page_context_icon(:unknown)
  end

  test "page_context_name returns localized name" do
    assert_equal "Dashboard", page_context_name(:dashboard)
    assert_equal "Transactions", page_context_name(:transactions)
  end
end
