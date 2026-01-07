class Settings::NotificationsController < ApplicationController
  layout "settings"

  def show
    @user = Current.user
  end

  def update
    @user = Current.user

    @user.update_budget_email_preferences(budget_email_params)

    respond_to do |format|
      format.html { redirect_to settings_notifications_path, notice: t(".success") }
      format.json { head :ok }
    end
  end

  private

  def budget_email_params
    params.require(:budget_email_settings).permit(:enabled, :exceeded_alerts, :warning_alerts, :warning_threshold)
  end
end
