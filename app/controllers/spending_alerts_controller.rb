class SpendingAlertsController < ApplicationController
  before_action :set_spending_alert

  def dismiss
    @spending_alert.dismiss!
    head :ok
  end

  private

  def set_spending_alert
    @spending_alert = Current.family.spending_alerts.find(params[:id])
  end
end
