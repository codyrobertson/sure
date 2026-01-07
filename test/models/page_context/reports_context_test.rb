require "test_helper"

class PageContext::ReportsContextTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "page_name returns :reports" do
    context = PageContext::ReportsContext.new(family: @family, user: @user)

    assert_equal :reports, context.page_name
  end

  test "page_icon returns chart-bar" do
    context = PageContext::ReportsContext.new(family: @family, user: @user)

    assert_equal "chart-bar", context.page_icon
  end

  test "available? returns true when transactions exist" do
    context = PageContext::ReportsContext.new(family: @family, user: @user)

    assert context.available?
  end

  test "prompts returns array of prompts" do
    context = PageContext::ReportsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.is_a?(Array)
    assert prompts.length <= PageContext::Base::MAX_PROMPTS
    prompts.each do |prompt|
      assert prompt[:icon].present?
      assert prompt[:text].present?
    end
  end

  test "includes income vs expenses prompt" do
    context = PageContext::ReportsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.any? { |p| p[:text] == I18n.t("ai_prompts.reports.income_vs_expenses") }
  end

  test "includes spending trends prompt" do
    context = PageContext::ReportsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.any? { |p| p[:text] == I18n.t("ai_prompts.reports.spending_trends") }
  end

  test "includes savings rate prompt" do
    context = PageContext::ReportsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.any? { |p| p[:text] == I18n.t("ai_prompts.reports.savings_rate") }
  end
end
