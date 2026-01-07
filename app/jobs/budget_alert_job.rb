class BudgetAlertJob < ApplicationJob
  queue_as :scheduled

  def perform(family_id = nil)
    families = family_id ? Family.where(id: family_id) : Family.all

    families.find_each do |family|
      check_budgets_for_family(family)
    rescue StandardError => e
      Rails.logger.error("Failed to check budget alerts for family #{family.id}: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    end
  end

  private

  def check_budgets_for_family(family)
    # Get the current month's budget
    budget = Budget.find_or_bootstrap(family, start_date: Date.current)
    return unless budget&.initialized?

    # Clean up old alert history records
    cleanup_old_alert_history(budget)

    # Find categories that are over budget or near limit
    over_budget_categories = budget.budget_categories.select(&:over_budget?)
    near_limit_categories = budget.budget_categories.select(&:near_limit?)

    # Send alerts to each user in the family based on their preferences
    family.users.active.find_each do |user|
      send_alerts_to_user(user, budget, over_budget_categories, near_limit_categories)
    rescue StandardError => e
      Rails.logger.error("Failed to send budget alert to user #{user.id}: #{e.message}")
    end
  end

  def send_alerts_to_user(user, budget, over_budget_categories, near_limit_categories)
    return unless user.budget_emails_enabled?

    # Filter near_limit_categories based on user's warning threshold
    filtered_near_limit = near_limit_categories.select do |bc|
      bc.percent_of_budget_spent >= user.budget_warning_threshold
    end

    # Send exceeded alerts for each category
    if user.budget_exceeded_emails_enabled?
      new_exceeded_categories = over_budget_categories.reject do |bc|
        BudgetAlertHistory.already_sent?(
          user: user,
          budget: budget,
          budget_category: bc,
          alert_type: "exceeded"
        )
      end

      if new_exceeded_categories.any?
        BudgetAlertMailer.with(
          user: user,
          budget: budget,
          over_budget_categories: new_exceeded_categories
        ).budget_exceeded.deliver_later

        new_exceeded_categories.each do |bc|
          BudgetAlertHistory.record_alert!(
            user: user,
            budget: budget,
            budget_category: bc,
            alert_type: "exceeded"
          )
        end

        Rails.logger.info("Sent budget exceeded email to user #{user.id} for #{new_exceeded_categories.count} categories")
      end
    end

    # Send warning alerts for each category
    if user.budget_warning_emails_enabled?
      new_warning_categories = filtered_near_limit.reject do |bc|
        BudgetAlertHistory.already_sent?(
          user: user,
          budget: budget,
          budget_category: bc,
          alert_type: "warning"
        )
      end

      if new_warning_categories.any?
        BudgetAlertMailer.with(
          user: user,
          budget: budget,
          near_limit_categories: new_warning_categories
        ).budget_warning.deliver_later

        new_warning_categories.each do |bc|
          BudgetAlertHistory.record_alert!(
            user: user,
            budget: budget,
            budget_category: bc,
            alert_type: "warning"
          )
        end

        Rails.logger.info("Sent budget warning email to user #{user.id} for #{new_warning_categories.count} categories")
      end
    end
  end

  # Clean up old budget alert history records to prevent unbounded growth
  # Keeps only the current budget's alert history
  def cleanup_old_alert_history(current_budget)
    BudgetAlertHistory.cleanup_old_records!(keep_budget_ids: [current_budget.id])
  end
end
