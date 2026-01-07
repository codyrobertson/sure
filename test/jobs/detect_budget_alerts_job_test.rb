require "test_helper"

class DetectBudgetAlertsJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
    @budget = budgets(:one)
  end

  test "performs for all families when no family_id provided" do
    Budget.stubs(:find_or_bootstrap).returns(@budget)
    @budget.stubs(:initialized?).returns(true)

    BudgetAlertDetector.any_instance.expects(:detect_and_create_alerts).returns([]).at_least_once

    DetectBudgetAlertsJob.perform_now
  end

  test "performs for specific family when family_id provided" do
    Budget.expects(:find_or_bootstrap).with(@family, start_date: Date.current).returns(@budget)
    @budget.stubs(:initialized?).returns(true)

    BudgetAlertDetector.any_instance.expects(:detect_and_create_alerts).returns([]).once

    DetectBudgetAlertsJob.perform_now(@family.id)
  end

  test "skips family if budget is not initialized" do
    Budget.stubs(:find_or_bootstrap).returns(@budget)
    @budget.stubs(:initialized?).returns(false)

    BudgetAlertDetector.any_instance.expects(:detect_and_create_alerts).never

    DetectBudgetAlertsJob.perform_now(@family.id)
  end

  test "skips family if no budget exists" do
    Budget.stubs(:find_or_bootstrap).returns(nil)

    BudgetAlertDetector.any_instance.expects(:detect_and_create_alerts).never

    DetectBudgetAlertsJob.perform_now(@family.id)
  end

  test "continues processing other families when one fails" do
    families = [ @family, families(:empty) ]
    Family.stubs(:all).returns(Family.where(id: families.map(&:id)))

    Budget.stubs(:find_or_bootstrap).raises(StandardError.new("Test error")).then.returns(@budget)
    @budget.stubs(:initialized?).returns(true)

    # Should still process the second family
    BudgetAlertDetector.any_instance.expects(:detect_and_create_alerts).returns([]).once

    # Should not raise
    assert_nothing_raised do
      DetectBudgetAlertsJob.perform_now
    end
  end

  test "logs created alerts" do
    Budget.stubs(:find_or_bootstrap).returns(@budget)
    @budget.stubs(:initialized?).returns(true)

    alert = BudgetAlert.new(id: SecureRandom.uuid)
    BudgetAlertDetector.any_instance.stubs(:detect_and_create_alerts).returns([ alert ])

    Rails.logger.expects(:info).with(includes("Created 1 budget alerts"))

    DetectBudgetAlertsJob.perform_now(@family.id)
  end
end
