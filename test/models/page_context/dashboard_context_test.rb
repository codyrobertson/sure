require "test_helper"

class PageContext::DashboardContextTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "page_name returns :dashboard" do
    context = PageContext::DashboardContext.new(family: @family, user: @user)

    assert_equal :dashboard, context.page_name
  end

  test "page_icon returns pie-chart" do
    context = PageContext::DashboardContext.new(family: @family, user: @user)

    assert_equal "pie-chart", context.page_icon
  end

  test "available? returns true when visible accounts exist" do
    context = PageContext::DashboardContext.new(family: @family, user: @user)

    assert context.available?
  end

  test "prompts returns array of prompts" do
    context = PageContext::DashboardContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.is_a?(Array)
    assert prompts.length <= PageContext::Base::MAX_PROMPTS
    prompts.each do |prompt|
      assert prompt[:icon].present?
      assert prompt[:text].present?
    end
  end

  test "includes net worth analysis prompt" do
    context = PageContext::DashboardContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.any? { |p| p[:icon] == "trending-up" }
  end
end
