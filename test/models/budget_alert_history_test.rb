require "test_helper"

class BudgetAlertHistoryTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = families(:dylan_family)
    @budget = Budget.find_or_bootstrap(@family, start_date: Date.current)
    @budget.sync_budget_categories
    @budget_category = @budget.budget_categories.first
  end

  test "validates alert_type presence" do
    history = BudgetAlertHistory.new(
      user: @user,
      budget: @budget,
      budget_category: @budget_category
    )
    assert_not history.valid?
    assert_includes history.errors[:alert_type], "can't be blank"
  end

  test "validates alert_type inclusion" do
    history = BudgetAlertHistory.new(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "invalid"
    )
    assert_not history.valid?
    assert_includes history.errors[:alert_type], "is not included in the list"
  end

  test "validates uniqueness of user per budget category and alert type" do
    BudgetAlertHistory.create!(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "exceeded"
    )

    duplicate = BudgetAlertHistory.new(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "exceeded"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already received this alert for this budget category"
  end

  test "allows same user to receive different alert types" do
    exceeded = BudgetAlertHistory.create!(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "exceeded"
    )

    warning = BudgetAlertHistory.new(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "warning"
    )
    assert warning.valid?
  end

  test "already_sent? returns true when alert exists" do
    BudgetAlertHistory.create!(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "exceeded"
    )

    assert BudgetAlertHistory.already_sent?(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "exceeded"
    )
  end

  test "already_sent? returns false when alert does not exist" do
    assert_not BudgetAlertHistory.already_sent?(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "exceeded"
    )
  end

  test "record_alert! creates new alert history" do
    # Stub budget_category methods
    @budget_category.stubs(:budgeted_spending).returns(100)
    @budget_category.stubs(:actual_spending).returns(150)
    @budget_category.stubs(:percent_of_budget_spent).returns(150)
    @budget_category.stubs(:currency).returns("USD")

    assert_difference "BudgetAlertHistory.count", 1 do
      BudgetAlertHistory.record_alert!(
        user: @user,
        budget: @budget,
        budget_category: @budget_category,
        alert_type: "exceeded"
      )
    end
  end

  test "record_alert! handles duplicate gracefully" do
    @budget_category.stubs(:budgeted_spending).returns(100)
    @budget_category.stubs(:actual_spending).returns(150)
    @budget_category.stubs(:percent_of_budget_spent).returns(150)
    @budget_category.stubs(:currency).returns("USD")

    # Create first record
    BudgetAlertHistory.record_alert!(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "exceeded"
    )

    # Second call should not raise and should not create duplicate
    assert_no_difference "BudgetAlertHistory.count" do
      result = BudgetAlertHistory.record_alert!(
        user: @user,
        budget: @budget,
        budget_category: @budget_category,
        alert_type: "exceeded"
      )
      assert_not_nil result
    end
  end

  test "cleanup_old_records! removes records from other budgets" do
    old_budget_id = SecureRandom.uuid

    # Create a record for an "old" budget (we'll simulate by creating directly)
    old_record = BudgetAlertHistory.create!(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "exceeded"
    )

    # Create another budget and category for current
    new_budget = Budget.find_or_bootstrap(@family, start_date: Date.current.next_month)
    new_budget.sync_budget_categories
    new_category = new_budget.budget_categories.first

    new_record = BudgetAlertHistory.create!(
      user: @user,
      budget: new_budget,
      budget_category: new_category,
      alert_type: "exceeded"
    )

    # Cleanup should remove old records
    BudgetAlertHistory.cleanup_old_records!(keep_budget_ids: [new_budget.id])

    assert_nil BudgetAlertHistory.find_by(id: old_record.id)
    assert BudgetAlertHistory.find_by(id: new_record.id).present?
  end

  test "scopes filter correctly" do
    @budget_category.stubs(:budgeted_spending).returns(100)
    @budget_category.stubs(:actual_spending).returns(150)
    @budget_category.stubs(:percent_of_budget_spent).returns(150)
    @budget_category.stubs(:currency).returns("USD")

    exceeded = BudgetAlertHistory.create!(
      user: @user,
      budget: @budget,
      budget_category: @budget_category,
      alert_type: "exceeded"
    )

    # Create warning for different category
    second_category = @budget.budget_categories.second
    warning = BudgetAlertHistory.create!(
      user: @user,
      budget: @budget,
      budget_category: second_category,
      alert_type: "warning"
    )

    assert_includes BudgetAlertHistory.exceeded, exceeded
    assert_not_includes BudgetAlertHistory.exceeded, warning

    assert_includes BudgetAlertHistory.warning, warning
    assert_not_includes BudgetAlertHistory.warning, exceeded

    assert_includes BudgetAlertHistory.for_budget(@budget), exceeded
    assert_includes BudgetAlertHistory.for_budget(@budget), warning

    assert_includes BudgetAlertHistory.for_user(@user), exceeded
    assert_includes BudgetAlertHistory.for_user(@user), warning
  end
end
