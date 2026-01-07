class BudgetEmailUnsubscribesController < ApplicationController
  skip_authentication only: %i[show create]
  layout "auth"

  def show
    @user = User.find_by_token_for(:budget_email_unsubscribe, params[:token])

    if @user.nil?
      flash[:alert] = t(".invalid_token")
      redirect_to root_path
    end
  end

  def create
    @user = User.find_by_token_for(:budget_email_unsubscribe, params[:token])

    if @user.nil?
      flash[:alert] = t(".invalid_token")
      redirect_to root_path
      return
    end

    @user.update_budget_email_preferences("enabled" => false)
    flash[:notice] = t(".success")
    redirect_to root_path
  end
end
