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

    # Send exceeded alert
    if over_budget_categories.any? && user.budget_exceeded_emails_enabled?
      unless already_sent_exceeded_alert?(user, budget, over_budget_categories)
        BudgetAlertMailer.with(
          user: user,
          budget: budget,
          over_budget_categories: over_budget_categories
        ).budget_exceeded.deliver_later

        record_sent_alert(user, budget, :exceeded, over_budget_categories)
        Rails.logger.info("Sent budget exceeded email to user #{user.id} for #{over_budget_categories.count} categories")
      end
    end

    # Send warning alert
    if filtered_near_limit.any? && user.budget_warning_emails_enabled?
      unless already_sent_warning_alert?(user, budget, filtered_near_limit)
        BudgetAlertMailer.with(
          user: user,
          budget: budget,
          near_limit_categories: filtered_near_limit
        ).budget_warning.deliver_later

        record_sent_alert(user, budget, :warning, filtered_near_limit)
        Rails.logger.info("Sent budget warning email to user #{user.id} for #{filtered_near_limit.count} categories")
      end
    end
  end

  # Track sent alerts in user preferences to avoid duplicate emails
  def already_sent_exceeded_alert?(user, budget, categories)
    sent_alerts = user.preferences&.dig("budget_alerts_sent", budget.id.to_s, "exceeded") || []
    category_ids = categories.map { |c| c.id.to_s }.sort
    sent_alerts.include?(category_ids)
  end

  def already_sent_warning_alert?(user, budget, categories)
    sent_alerts = user.preferences&.dig("budget_alerts_sent", budget.id.to_s, "warning") || []
    category_ids = categories.map { |c| c.id.to_s }.sort
    sent_alerts.include?(category_ids)
  end

  def record_sent_alert(user, budget, alert_type, categories)
    category_ids = categories.map { |c| c.id.to_s }.sort

    user.transaction do
      user.lock!
      updated_prefs = (user.preferences || {}).deep_dup
      updated_prefs["budget_alerts_sent"] ||= {}
      updated_prefs["budget_alerts_sent"][budget.id.to_s] ||= {}
      updated_prefs["budget_alerts_sent"][budget.id.to_s][alert_type.to_s] ||= []
      updated_prefs["budget_alerts_sent"][budget.id.to_s][alert_type.to_s] << category_ids
      user.update!(preferences: updated_prefs)
    end
  end
end
