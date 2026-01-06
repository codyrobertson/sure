require "test_helper"

class BudgetAlertDetectorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @budget = budgets(:one)
    @detector = BudgetAlertDetector.new(@budget)
  end

  test "detect returns empty array for uninitialized budget" do
    @budget.update!(budgeted_spending: nil)
    assert_equal [], @detector.detect
  end

  test "detect returns alerts when spending exceeds threshold" do
    # Stub the budget to return 60% spent
    @budget.stubs(:percent_of_budget_spent).returns(60)
    @budget.stubs(:actual_spending).returns(3000)
    @budget.stubs(:budgeted_spending).returns(5000)
    @budget.stubs(:initialized?).returns(true)
    @budget.stubs(:budget_categories).returns([])

    alerts = @detector.detect
    assert_equal 1, alerts.count
    assert_equal :threshold_50, alerts.first[:alert_type]
    assert_equal :info, alerts.first[:severity]
  end

  test "detect returns warning severity at 80% threshold" do
    @budget.stubs(:percent_of_budget_spent).returns(85)
    @budget.stubs(:actual_spending).returns(4250)
    @budget.stubs(:budgeted_spending).returns(5000)
    @budget.stubs(:initialized?).returns(true)
    @budget.stubs(:budget_categories).returns([])

    alerts = @detector.detect
    assert_equal 1, alerts.count
    assert_equal :threshold_80, alerts.first[:alert_type]
    assert_equal :warning, alerts.first[:severity]
  end

  test "detect returns critical severity when overspent" do
    @budget.stubs(:percent_of_budget_spent).returns(110)
    @budget.stubs(:actual_spending).returns(5500)
    @budget.stubs(:budgeted_spending).returns(5000)
    @budget.stubs(:initialized?).returns(true)
    @budget.stubs(:budget_categories).returns([])

    alerts = @detector.detect
    assert_equal 1, alerts.count
    assert_equal :overspent, alerts.first[:alert_type]
    assert_equal :critical, alerts.first[:severity]
  end

  test "detect returns only highest threshold alert" do
    # Even when multiple thresholds are crossed, only return the highest
    @budget.stubs(:percent_of_budget_spent).returns(95)
    @budget.stubs(:actual_spending).returns(4750)
    @budget.stubs(:budgeted_spending).returns(5000)
    @budget.stubs(:initialized?).returns(true)
    @budget.stubs(:budget_categories).returns([])

    alerts = @detector.detect
    assert_equal 1, alerts.count
    assert_equal :threshold_80, alerts.first[:alert_type]
  end

  test "detect includes category alerts" do
    budget_category = mock("budget_category")
    budget_category.stubs(:budgeted_spending).returns(1000)
    budget_category.stubs(:percent_of_budget_spent).returns(75)
    budget_category.stubs(:actual_spending).returns(750)
    budget_category.stubs(:category).returns(stub(name: "Food"))

    @budget.stubs(:percent_of_budget_spent).returns(40)
    @budget.stubs(:actual_spending).returns(2000)
    @budget.stubs(:budgeted_spending).returns(5000)
    @budget.stubs(:initialized?).returns(true)
    @budget.stubs(:budget_categories).returns([ budget_category ])

    alerts = @detector.detect
    # Should have one category alert (50% threshold crossed)
    category_alerts = alerts.select { |a| a[:budget_category].present? }
    assert_equal 1, category_alerts.count
    assert_equal :threshold_50, category_alerts.first[:alert_type]
  end

  test "detect_and_create_alerts creates budget alert records" do
    # Clear existing alerts
    @budget.budget_alerts.destroy_all

    @budget.stubs(:percent_of_budget_spent).returns(85)
    @budget.stubs(:actual_spending).returns(4250)
    @budget.stubs(:budgeted_spending).returns(5000)
    @budget.stubs(:initialized?).returns(true)
    @budget.stubs(:budget_categories).returns([])

    assert_difference "BudgetAlert.count", 1 do
      @detector.detect_and_create_alerts
    end

    alert = @budget.budget_alerts.last
    assert_equal "threshold_80", alert.alert_type
    assert_equal "warning", alert.severity
    assert alert.active?
  end

  test "detect_and_create_alerts does not create duplicate alerts" do
    @budget.stubs(:percent_of_budget_spent).returns(85)
    @budget.stubs(:actual_spending).returns(4250)
    @budget.stubs(:budgeted_spending).returns(5000)
    @budget.stubs(:initialized?).returns(true)
    @budget.stubs(:budget_categories).returns([])

    # Create first alert
    @detector.detect_and_create_alerts

    # Try to create again - should not create duplicate
    assert_no_difference "BudgetAlert.count" do
      @detector.detect_and_create_alerts
    end
  end

  test "detect_and_create_alerts upgrades existing alert when severity increases" do
    # Clear existing alerts
    @budget.budget_alerts.destroy_all

    # Create initial 80% alert
    @budget.stubs(:percent_of_budget_spent).returns(85)
    @budget.stubs(:actual_spending).returns(4250)
    @budget.stubs(:budgeted_spending).returns(5000)
    @budget.stubs(:initialized?).returns(true)
    @budget.stubs(:budget_categories).returns([])

    @detector.detect_and_create_alerts
    alert = @budget.budget_alerts.active.first
    assert_equal "threshold_80", alert.alert_type

    # Now simulate overspending
    @budget.stubs(:percent_of_budget_spent).returns(110)
    @budget.stubs(:actual_spending).returns(5500)

    @detector.detect_and_create_alerts
    alert.reload

    assert_equal "overspent", alert.alert_type
    assert_equal "critical", alert.severity
  end

  test "thresholds constant is correct" do
    assert_equal [ 50, 80, 100 ], BudgetAlertDetector::THRESHOLDS
  end
end
