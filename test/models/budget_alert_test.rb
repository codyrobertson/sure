require "test_helper"

class BudgetAlertTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @budget = budgets(:one)
    @alert = budget_alerts(:threshold_50_alert)
  end

  test "active scope returns only non-dismissed alerts" do
    active_alerts = BudgetAlert.active
    assert active_alerts.include?(budget_alerts(:threshold_50_alert))
    assert active_alerts.include?(budget_alerts(:threshold_80_alert))
    assert_not active_alerts.include?(budget_alerts(:dismissed_budget_alert))
  end

  test "dismissed scope returns only dismissed alerts" do
    dismissed_alerts = BudgetAlert.dismissed
    assert dismissed_alerts.include?(budget_alerts(:dismissed_budget_alert))
    assert_not dismissed_alerts.include?(budget_alerts(:threshold_50_alert))
  end

  test "for_period returns alerts for specific period" do
    period = Period.custom(
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month
    )
    alerts = @family.budget_alerts.for_period(period)
    assert alerts.include?(budget_alerts(:threshold_50_alert))
    assert alerts.include?(budget_alerts(:threshold_80_alert))
    assert_not alerts.include?(budget_alerts(:overspent_alert))
  end

  test "for_budget returns alerts for specific budget" do
    alerts = BudgetAlert.for_budget(@budget)
    assert alerts.include?(budget_alerts(:threshold_50_alert))
  end

  test "dismiss marks alert as dismissed" do
    alert = budget_alerts(:threshold_50_alert)
    assert alert.active?
    assert_not alert.dismissed?

    alert.dismiss!

    assert_not alert.active?
    assert alert.dismissed?
    assert_not_nil alert.dismissed_at
  end

  test "alert type helpers work correctly" do
    threshold_50 = budget_alerts(:threshold_50_alert)
    threshold_80 = budget_alerts(:threshold_80_alert)
    overspent = budget_alerts(:overspent_alert)

    assert threshold_50.alert_type_threshold_50?
    assert_not threshold_50.alert_type_threshold_80?

    assert threshold_80.alert_type_threshold_80?
    assert_not threshold_80.alert_type_overspent?

    assert overspent.alert_type_overspent?
    assert_not overspent.alert_type_threshold_50?
  end

  test "severity helpers work correctly" do
    info_alert = budget_alerts(:threshold_50_alert)
    warning_alert = budget_alerts(:threshold_80_alert)
    critical_alert = budget_alerts(:overspent_alert)

    assert info_alert.severity_info?
    assert_not info_alert.severity_warning?

    assert warning_alert.severity_warning?
    assert_not warning_alert.severity_critical?

    assert critical_alert.severity_critical?
    assert_not critical_alert.severity_info?
  end

  test "validates required fields" do
    alert = BudgetAlert.new(family: @family, budget: @budget)
    assert_not alert.valid?
    assert_includes alert.errors[:alert_type], "can't be blank"
    assert_includes alert.errors[:severity], "can't be blank"
    assert_includes alert.errors[:period_start_date], "can't be blank"
    assert_includes alert.errors[:period_end_date], "can't be blank"
  end

  test "overall_budget_alert? returns true when no category" do
    assert @alert.overall_budget_alert?
    assert_not @alert.category_alert?
  end

  test "threshold_percent returns correct value" do
    assert_equal 50, budget_alerts(:threshold_50_alert).threshold_percent
    assert_equal 80, budget_alerts(:threshold_80_alert).threshold_percent
  end

  test "severity_for_threshold returns correct severity" do
    assert_equal :info, BudgetAlert.severity_for_threshold(50)
    assert_equal :warning, BudgetAlert.severity_for_threshold(80)
    assert_equal :critical, BudgetAlert.severity_for_threshold(100)
    assert_equal :critical, BudgetAlert.severity_for_threshold(120)
  end

  test "THRESHOLDS constant is defined correctly" do
    assert_equal({ threshold_50: 50, threshold_80: 80, threshold_100: 100 }, BudgetAlert::THRESHOLDS)
  end
end
