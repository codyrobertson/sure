require "test_helper"

class BudgetEmailUnsubscribesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.update!(preferences: {})
    @user.update_budget_email_preferences("enabled" => true)
  end

  test "show displays unsubscribe page with valid token" do
    token = @user.generate_token_for(:budget_email_unsubscribe)

    get budget_email_unsubscribe_url(token: token)

    assert_response :success
  end

  test "show redirects with invalid token" do
    get budget_email_unsubscribe_url(token: "invalid-token")

    assert_redirected_to root_path
    assert_equal I18n.t("budget_email_unsubscribes.show.invalid_token"), flash[:alert]
  end

  test "create unsubscribes user with valid token" do
    token = @user.generate_token_for(:budget_email_unsubscribe)

    assert @user.budget_emails_enabled?

    post budget_email_unsubscribe_url(token: token)

    assert_redirected_to root_path
    assert_equal I18n.t("budget_email_unsubscribes.create.success"), flash[:notice]

    @user.reload
    assert_not @user.budget_emails_enabled?
  end

  test "create redirects with invalid token" do
    post budget_email_unsubscribe_url(token: "invalid-token")

    assert_redirected_to root_path
    assert_equal I18n.t("budget_email_unsubscribes.create.invalid_token"), flash[:alert]
  end

  test "unsubscribe works without authentication" do
    # Ensure we're not signed in
    token = @user.generate_token_for(:budget_email_unsubscribe)

    get budget_email_unsubscribe_url(token: token)
    assert_response :success

    post budget_email_unsubscribe_url(token: token)
    assert_redirected_to root_path

    @user.reload
    assert_not @user.budget_emails_enabled?
  end
end
