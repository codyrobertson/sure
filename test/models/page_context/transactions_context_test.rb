require "test_helper"

class PageContext::TransactionsContextTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "page_name returns :transactions" do
    context = PageContext::TransactionsContext.new(family: @family, user: @user)

    assert_equal :transactions, context.page_name
  end

  test "page_icon returns credit-card" do
    context = PageContext::TransactionsContext.new(family: @family, user: @user)

    assert_equal "credit-card", context.page_icon
  end

  test "available? returns true when transactions exist" do
    context = PageContext::TransactionsContext.new(family: @family, user: @user)

    assert context.available?
  end

  test "prompts returns array of prompts" do
    context = PageContext::TransactionsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.is_a?(Array)
    assert prompts.length <= PageContext::Base::MAX_PROMPTS
    prompts.each do |prompt|
      assert prompt[:icon].present?
      assert prompt[:text].present?
    end
  end

  test "prompts are cached" do
    context = PageContext::TransactionsContext.new(family: @family, user: @user)

    first_call = context.prompts
    second_call = context.prompts

    assert_equal first_call, second_call
  end

  test "includes filter prompt when has_filters metadata is true" do
    context = PageContext::TransactionsContext.new(
      family: @family,
      user: @user,
      metadata: { has_filters: true }
    )
    prompts = context.prompts

    assert prompts.any? { |p| p[:text].include?(I18n.t("ai_prompts.transactions.analyze_filtered_results")) }
  end
end
