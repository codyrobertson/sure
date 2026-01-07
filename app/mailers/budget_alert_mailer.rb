class BudgetAlertMailer < ApplicationMailer
  helper ApplicationHelper
  helper ActionView::Helpers::NumberHelper

  def budget_exceeded
    @user = params[:user]
    @budget = params[:budget]
    @over_budget_categories = params[:over_budget_categories]
    @subject = t(".subject", product_name: product_name)

    mail to: @user.email, subject: @subject
  end

  def budget_warning
    @user = params[:user]
    @budget = params[:budget]
    @near_limit_categories = params[:near_limit_categories]
    @subject = t(".subject", product_name: product_name)

    mail to: @user.email, subject: @subject
  end
end
