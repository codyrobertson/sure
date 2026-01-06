require "test_helper"

class SpendingAlertTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @category = categories(:food_and_drink)
    @alert = spending_alerts(:category_anomaly_alert)
  end

  test "active scope returns only non-dismissed alerts" do
    active_alerts = SpendingAlert.active
    assert active_alerts.include?(spending_alerts(:category_anomaly_alert))
    assert active_alerts.include?(spending_alerts(:new_merchant_alert))
    assert_not active_alerts.include?(spending_alerts(:dismissed_alert))
  end

  test "dismissed scope returns only dismissed alerts" do
    dismissed_alerts = SpendingAlert.dismissed
    assert dismissed_alerts.include?(spending_alerts(:dismissed_alert))
    assert_not dismissed_alerts.include?(spending_alerts(:category_anomaly_alert))
  end

  test "for_period returns alerts for specific period" do
    period = Period.custom(
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month
    )
    alerts = @family.spending_alerts.for_period(period)
    assert alerts.include?(spending_alerts(:category_anomaly_alert))
    assert alerts.include?(spending_alerts(:new_merchant_alert))
  end

  test "dismiss marks alert as dismissed" do
    alert = spending_alerts(:category_anomaly_alert)
    assert alert.active?
    assert_not alert.dismissed?

    alert.dismiss!

    assert_not alert.active?
    assert alert.dismissed?
    assert_not_nil alert.dismissed_at
  end

  test "alert type helpers work correctly" do
    category_alert = spending_alerts(:category_anomaly_alert)
    merchant_alert = spending_alerts(:new_merchant_alert)

    assert category_alert.alert_type_category_anomaly?
    assert_not category_alert.alert_type_new_merchant?

    assert merchant_alert.alert_type_new_merchant?
    assert_not merchant_alert.alert_type_category_anomaly?
  end

  test "severity helpers work correctly" do
    warning_alert = spending_alerts(:category_anomaly_alert)
    alert_alert = spending_alerts(:dismissed_alert)

    assert warning_alert.severity_warning?
    assert_not warning_alert.severity_alert?

    assert alert_alert.severity_alert?
    assert_not alert_alert.severity_warning?
  end

  test "top_transactions returns array from metadata" do
    alert = spending_alerts(:category_anomaly_alert)
    assert_equal [], alert.top_transactions
  end

  test "merchant_name returns value from metadata" do
    alert = spending_alerts(:new_merchant_alert)
    assert_equal "New Coffee Shop", alert.merchant_name
  end

  test "validates required fields" do
    alert = SpendingAlert.new(family: @family)
    assert_not alert.valid?
    assert_includes alert.errors[:alert_type], "can't be blank"
    assert_includes alert.errors[:severity], "can't be blank"
    assert_includes alert.errors[:period_start_date], "can't be blank"
    assert_includes alert.errors[:period_end_date], "can't be blank"
  end

  test "create_from_anomaly_analysis creates category anomaly alerts" do
    period = Period.custom(
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month
    )

    analysis = {
      anomalies: [
        {
          category: { id: @category.id, name: "Food & Drink", color: "#fd7f6f" },
          current: { amount: 600.0, formatted: "$600.00" },
          average: { amount: 200.0, formatted: "$200.00" },
          deviation_percent: 300.0,
          severity: :alert,
          top_transactions: []
        }
      ],
      new_merchants: []
    }

    # Clear existing alerts for this period
    @family.spending_alerts.for_period(period).where(category: @category).destroy_all

    alerts = SpendingAlert.create_from_anomaly_analysis(@family, period, analysis)
    assert_equal 1, alerts.count

    alert = alerts.first
    assert alert.alert_type_category_anomaly?
    assert alert.severity_alert?
    assert_equal 600.0, alert.current_amount
    assert_equal 200.0, alert.average_amount
    assert_equal 300.0, alert.deviation_percent
  end
end
