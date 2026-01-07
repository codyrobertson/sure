require "test_helper"

class PageContext::InvestmentsContextTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "page_name returns :investments" do
    context = PageContext::InvestmentsContext.new(family: @family, user: @user)

    assert_equal :investments, context.page_name
  end

  test "page_icon returns chart-candlestick" do
    context = PageContext::InvestmentsContext.new(family: @family, user: @user)

    assert_equal "chart-candlestick", context.page_icon
  end

  test "available? returns true when investment accounts exist" do
    # Ensure the family has investment accounts
    assert @family.accounts.where(accountable_type: "Investment").exists?,
           "Test requires family to have investment accounts"

    context = PageContext::InvestmentsContext.new(family: @family, user: @user)
    assert context.available?
  end

  test "available? returns false when no investment accounts exist" do
    family_without_investments = families(:empty)

    context = PageContext::InvestmentsContext.new(family: family_without_investments, user: @user)
    assert_not context.available?
  end

  test "prompts returns array of prompts" do
    context = PageContext::InvestmentsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.is_a?(Array)
    assert prompts.length <= PageContext::Base::MAX_PROMPTS
    prompts.each do |prompt|
      assert prompt[:icon].present?
      assert prompt[:text].present?
    end
  end

  test "includes portfolio performance prompt" do
    context = PageContext::InvestmentsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.any? { |p| p[:text] == I18n.t("ai_prompts.investments.portfolio_performance") }
  end

  test "includes asset allocation prompt" do
    context = PageContext::InvestmentsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.any? { |p| p[:text] == I18n.t("ai_prompts.investments.asset_allocation") }
  end

  test "includes investment comparison prompt" do
    context = PageContext::InvestmentsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.any? { |p| p[:text] == I18n.t("ai_prompts.investments.investment_comparison") }
  end
end
