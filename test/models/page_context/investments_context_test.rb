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
    context = PageContext::InvestmentsContext.new(family: @family, user: @user)

    assert context.available? == @family.accounts.where(accountable_type: "Investment").exists?
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
