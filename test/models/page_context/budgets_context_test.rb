require "test_helper"

class PageContext::BudgetsContextTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "page_name returns :budgets" do
    context = PageContext::BudgetsContext.new(family: @family, user: @user)

    assert_equal :budgets, context.page_name
  end

  test "page_icon returns map" do
    context = PageContext::BudgetsContext.new(family: @family, user: @user)

    assert_equal "map", context.page_icon
  end

  test "available? returns true even without budgets" do
    context = PageContext::BudgetsContext.new(family: @family, user: @user)

    assert context.available?
  end

  test "prompts returns array of prompts" do
    context = PageContext::BudgetsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.is_a?(Array)
    assert prompts.length <= PageContext::Base::MAX_PROMPTS
    prompts.each do |prompt|
      assert prompt[:icon].present?
      assert prompt[:text].present?
    end
  end

  test "includes budget tracking prompts when budgets exist" do
    context = PageContext::BudgetsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.any? { |p| p[:text] == I18n.t("ai_prompts.budgets.budget_vs_actual") }
  end

  test "includes create budget prompt when no budgets exist" do
    family_without_budgets = families(:empty)
    context = PageContext::BudgetsContext.new(family: family_without_budgets, user: @user)
    prompts = context.prompts

    assert prompts.any? { |p| p[:text] == I18n.t("ai_prompts.budgets.create_budget") }
  end
end
