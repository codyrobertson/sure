require "test_helper"

class BudgetAlertJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
    @user = users(:family_admin)
    @budget = budgets(:one)
  end

  test "job runs without error for family with no budget" do
    empty_family = families(:empty)
    assert_nothing_raised do
      BudgetAlertJob.perform_now(empty_family.id)
    end
  end

  test "job runs without error for specific family" do
    # Stub budget methods to avoid complex setup
    Budget.stubs(:find_or_bootstrap).returns(nil)

    assert_nothing_raised do
      BudgetAlertJob.perform_now(@family.id)
    end
  end

  test "job processes all families when no family_id provided" do
    Budget.stubs(:find_or_bootstrap).returns(nil)

    assert_nothing_raised do
      BudgetAlertJob.perform_now
    end
  end

  test "job does not send email when user has budget emails disabled" do
    # Mock budget with over-budget category
    mock_budget = stub(
      initialized?: true,
      budget_categories: [
        stub(over_budget?: true, near_limit?: false)
      ]
    )
    Budget.stubs(:find_or_bootstrap).returns(mock_budget)

    # Disable budget emails for user
    @user.update_budget_email_preferences("enabled" => false)

    assert_no_enqueued_emails do
      BudgetAlertJob.perform_now(@family.id)
    end
  end

  test "job sends exceeded email when category is over budget" do
    category = categories(:food_and_drink)

    # Create a budget category that is over budget
    budget_category = stub(
      id: SecureRandom.uuid,
      over_budget?: true,
      near_limit?: false,
      name: "Food & Drink",
      budgeted_spending_money: Money.new(100, "USD"),
      actual_spending_money: Money.new(150, "USD"),
      available_to_spend_money: Money.new(-50, "USD"),
      percent_of_budget_spent: 150
    )

    mock_budget = stub(
      id: @budget.id,
      initialized?: true,
      budget_categories: [budget_category]
    )

    Budget.stubs(:find_or_bootstrap).returns(mock_budget)

    # Ensure user has budget emails enabled (default)
    @user.update_budget_email_preferences("enabled" => true, "exceeded_alerts" => true)

    # Clear any existing alert tracking
    @user.transaction do
      @user.lock!
      updated_prefs = (@user.preferences || {}).deep_dup
      updated_prefs.delete("budget_alerts_sent")
      @user.update!(preferences: updated_prefs)
    end

    assert_enqueued_emails 1 do
      BudgetAlertJob.perform_now(@family.id)
    end
  end

  test "job does not send duplicate exceeded emails" do
    category = categories(:food_and_drink)

    budget_category = stub(
      id: "test-cat-id",
      over_budget?: true,
      near_limit?: false,
      name: "Food & Drink",
      budgeted_spending_money: Money.new(100, "USD"),
      actual_spending_money: Money.new(150, "USD"),
      available_to_spend_money: Money.new(-50, "USD"),
      percent_of_budget_spent: 150
    )

    mock_budget = stub(
      id: @budget.id,
      initialized?: true,
      budget_categories: [budget_category]
    )

    Budget.stubs(:find_or_bootstrap).returns(mock_budget)

    # Ensure user has budget emails enabled
    @user.update_budget_email_preferences("enabled" => true, "exceeded_alerts" => true)

    # Clear existing tracking first
    @user.transaction do
      @user.lock!
      updated_prefs = (@user.preferences || {}).deep_dup
      updated_prefs.delete("budget_alerts_sent")
      @user.update!(preferences: updated_prefs)
    end

    # First run should send email
    assert_enqueued_emails 1 do
      BudgetAlertJob.perform_now(@family.id)
    end

    # Second run should not send duplicate
    assert_no_enqueued_emails do
      BudgetAlertJob.perform_now(@family.id)
    end
  end

  test "job respects warning threshold preference" do
    budget_category_at_85 = stub(
      id: "cat-85",
      over_budget?: false,
      near_limit?: true,
      name: "Category at 85%",
      budgeted_spending_money: Money.new(100, "USD"),
      actual_spending_money: Money.new(85, "USD"),
      available_to_spend_money: Money.new(15, "USD"),
      percent_of_budget_spent: 85
    )

    mock_budget = stub(
      id: @budget.id,
      initialized?: true,
      budget_categories: [budget_category_at_85]
    )

    Budget.stubs(:find_or_bootstrap).returns(mock_budget)

    # Set threshold to 90% - shouldn't send email for 85% category
    @user.update_budget_email_preferences(
      "enabled" => true,
      "warning_alerts" => true,
      "warning_threshold" => 90
    )

    # Clear any existing tracking
    @user.transaction do
      @user.lock!
      updated_prefs = (@user.preferences || {}).deep_dup
      updated_prefs.delete("budget_alerts_sent")
      @user.update!(preferences: updated_prefs)
    end

    assert_no_enqueued_emails do
      BudgetAlertJob.perform_now(@family.id)
    end
  end
end
