require "test_helper"

class Settings::NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    sign_in @user
  end

  test "get show" do
    get settings_notifications_url
    assert_response :success
  end

  test "update budget email preferences" do
    patch settings_notifications_url, params: {
      budget_email_settings: {
        enabled: "1",
        exceeded_alerts: "1",
        warning_alerts: "0",
        warning_threshold: "85"
      }
    }

    assert_redirected_to settings_notifications_path

    @user.reload
    assert @user.budget_emails_enabled?
    assert @user.budget_exceeded_emails_enabled?
    assert_not @user.budget_warning_emails_enabled?
    assert_equal 85, @user.budget_warning_threshold
  end

  test "disable all budget emails" do
    patch settings_notifications_url, params: {
      budget_email_settings: {
        enabled: "0"
      }
    }

    assert_redirected_to settings_notifications_path

    @user.reload
    assert_not @user.budget_emails_enabled?
  end
end
