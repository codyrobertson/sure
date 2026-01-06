class BudgetAlertDetector
  THRESHOLDS = [ 50, 80, 100 ].freeze

  attr_reader :budget

  def initialize(budget)
    @budget = budget
  end

  def detect
    return [] unless budget.initialized?

    alerts = []
    alerts.concat(detect_overall_budget_alerts)
    alerts.concat(detect_category_alerts)
    alerts.compact
  end

  def detect_and_create_alerts
    detected = detect
    created = []

    detected.each do |alert_data|
      alert = create_or_update_alert(alert_data)
      created << alert if alert
    end

    created
  end

  private

  def detect_overall_budget_alerts
    alerts = []
    percent_spent = budget.percent_of_budget_spent

    THRESHOLDS.each do |threshold|
      next unless percent_spent >= threshold

      # Check if a higher threshold is already met
      next if alerts.any? { |a| a[:threshold] > threshold }

      alerts << build_alert_data(
        alert_type: alert_type_for_threshold(threshold, percent_spent),
        severity: severity_for_threshold(threshold, percent_spent),
        percent_spent: percent_spent,
        threshold: threshold,
        current_amount: budget.actual_spending,
        budgeted_amount: budget.budgeted_spending,
        budget_category: nil
      )
    end

    # Return only the highest threshold alert
    alerts.last(1)
  end

  def detect_category_alerts
    alerts = []

    budget.budget_categories.each do |bc|
      next if bc.budgeted_spending.nil? || bc.budgeted_spending.zero?

      percent_spent = bc.percent_of_budget_spent
      next unless percent_spent && percent_spent >= THRESHOLDS.first

      highest_threshold = THRESHOLDS.reverse.find { |t| percent_spent >= t }
      next unless highest_threshold

      alerts << build_alert_data(
        alert_type: alert_type_for_threshold(highest_threshold, percent_spent),
        severity: severity_for_threshold(highest_threshold, percent_spent),
        percent_spent: percent_spent,
        threshold: highest_threshold,
        current_amount: bc.actual_spending,
        budgeted_amount: bc.budgeted_spending,
        budget_category: bc
      )
    end

    alerts
  end

  def build_alert_data(alert_type:, severity:, percent_spent:, threshold:, current_amount:, budgeted_amount:, budget_category:)
    {
      alert_type: alert_type,
      severity: severity,
      percent_spent: percent_spent.round(1),
      threshold: threshold,
      current_amount: current_amount,
      budgeted_amount: budgeted_amount,
      budget_category: budget_category,
      category_name: budget_category&.category&.name
    }
  end

  def alert_type_for_threshold(threshold, percent_spent)
    if percent_spent > 100
      :overspent
    else
      :"threshold_#{threshold}"
    end
  end

  def severity_for_threshold(threshold, percent_spent)
    if percent_spent > 100 || threshold == 100
      :critical
    elsif threshold >= 80
      :warning
    else
      :info
    end
  end

  def create_or_update_alert(alert_data)
    # Find existing active alert for this budget/category/type combination
    existing = find_existing_alert(alert_data)

    if existing
      # Update if the threshold has increased
      if should_upgrade_alert?(existing, alert_data)
        existing.update!(
          alert_type: alert_data[:alert_type],
          severity: alert_data[:severity],
          current_amount: alert_data[:current_amount],
          budgeted_amount: alert_data[:budgeted_amount],
          spent_percent: alert_data[:percent_spent],
          metadata: build_metadata(alert_data)
        )
        return existing
      end
      return nil # No change needed
    end

    # Create new alert if no active alert exists
    create_alert(alert_data)
  end

  def find_existing_alert(alert_data)
    scope = budget.budget_alerts.active
      .where(budget_category: alert_data[:budget_category])

    # Find any active alert for this budget/category combination
    scope.first
  end

  def should_upgrade_alert?(existing, new_data)
    # Upgrade if the new severity is higher
    severity_order = { info: 0, warning: 1, critical: 2 }
    existing_severity = severity_order[existing.severity.to_sym] || 0
    new_severity = severity_order[new_data[:severity]] || 0

    new_severity > existing_severity ||
      new_data[:percent_spent] > (existing.spent_percent || 0)
  end

  def create_alert(alert_data)
    # Check for duplicate (deduplication logic)
    return nil if duplicate_exists?(alert_data)

    BudgetAlert.create!(
      family: budget.family,
      budget: budget,
      budget_category: alert_data[:budget_category],
      alert_type: alert_data[:alert_type],
      severity: alert_data[:severity],
      current_amount: alert_data[:current_amount],
      budgeted_amount: alert_data[:budgeted_amount],
      spent_percent: alert_data[:percent_spent],
      period_start_date: budget.start_date,
      period_end_date: budget.end_date,
      metadata: build_metadata(alert_data)
    )
  end

  def duplicate_exists?(alert_data)
    # Check if an identical alert was dismissed recently (within same budget period)
    budget.budget_alerts
      .dismissed
      .where(budget_category: alert_data[:budget_category])
      .where(alert_type: alert_data[:alert_type])
      .where(period_start_date: budget.start_date)
      .where(period_end_date: budget.end_date)
      .exists?
  end

  def build_metadata(alert_data)
    {
      "category_name" => alert_data[:category_name],
      "threshold_triggered" => alert_data[:threshold],
      "detection_time" => Time.current.iso8601
    }
  end
end
