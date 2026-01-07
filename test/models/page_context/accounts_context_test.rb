require "test_helper"

class PageContext::AccountsContextTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
  end

  test "page_name returns :accounts" do
    context = PageContext::AccountsContext.new(family: @family, user: @user)

    assert_equal :accounts, context.page_name
  end

  test "page_icon returns landmark" do
    context = PageContext::AccountsContext.new(family: @family, user: @user)

    assert_equal "landmark", context.page_icon
  end

  test "available? returns true when visible accounts exist" do
    context = PageContext::AccountsContext.new(family: @family, user: @user)

    assert context.available?
  end

  test "prompts returns array of prompts" do
    context = PageContext::AccountsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.is_a?(Array)
    assert prompts.length <= PageContext::Base::MAX_PROMPTS
    prompts.each do |prompt|
      assert prompt[:icon].present?
      assert prompt[:text].present?
    end
  end

  test "includes account-specific prompts when account_id is provided" do
    account = @family.accounts.first
    context = PageContext::AccountsContext.new(
      family: @family,
      user: @user,
      metadata: { account_id: account.id }
    )
    prompts = context.prompts

    assert prompts.any? { |p| p[:text].include?(account.name) }
  end

  test "includes general prompts when no account_id is provided" do
    context = PageContext::AccountsContext.new(family: @family, user: @user)
    prompts = context.prompts

    assert prompts.any? { |p| p[:text] == I18n.t("ai_prompts.accounts.compare_accounts") }
  end
end
