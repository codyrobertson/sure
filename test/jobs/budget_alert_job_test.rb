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
      id: @budget.id,
      initialized?: true,
      budget_categories: [
        stub(id: SecureRandom.uuid, over_budget?: true, near_limit?: false)
      ]
    )
    Budget.stubs(:find_or_bootstrap).returns(mock_budget)
    BudgetAlertHistory.stubs(:cleanup_old_records!)

    # Disable budget emails for user
    @user.update_budget_email_preferences("enabled" => false)

    assert_no_enqueued_emails do
      BudgetAlertJob.perform_now(@family.id)
    end
  end

  test "job sends exceeded email when category is over budget" do
    category_id = SecureRandom.uuid
    category = categories(:food_and_drink)

    # Create a budget category that is over budget
    budget_category = stub(
      id: category_id,
      over_budget?: true,
      near_limit?: false,
      name: "Food & Drink",
      budgeted_spending: 100,
      budgeted_spending_money: Money.new(100, "USD"),
      actual_spending: 150,
      actual_spending_money: Money.new(150, "USD"),
      available_to_spend_money: Money.new(-50, "USD"),
      percent_of_budget_spent: 150,
      currency: "USD"
    )

    mock_budget = stub(
      id: @budget.id,
      initialized?: true,
      budget_categories: [budget_category]
    )

    Budget.stubs(:find_or_bootstrap).returns(mock_budget)
    BudgetAlertHistory.stubs(:cleanup_old_records!)
    BudgetAlertHistory.stubs(:already_sent?).returns(false)
    BudgetAlertHistory.stubs(:record_alert!)

    # Ensure user has budget emails enabled (default)
    @user.update_budget_email_preferences("enabled" => true, "exceeded_alerts" => true)

    assert_enqueued_emails 1 do
      BudgetAlertJob.perform_now(@family.id)
    end
  end

  test "job does not send duplicate exceeded emails" do
    category_id = SecureRandom.uuid

    budget_category = stub(
      id: category_id,
      over_budget?: true,
      near_limit?: false,
      name: "Food & Drink",
      budgeted_spending: 100,
      budgeted_spending_money: Money.new(100, "USD"),
      actual_spending: 150,
      actual_spending_money: Money.new(150, "USD"),
      available_to_spend_money: Money.new(-50, "USD"),
      percent_of_budget_spent: 150,
      currency: "USD"
    )

    mock_budget = stub(
      id: @budget.id,
      initialized?: true,
      budget_categories: [budget_category]
    )

    Budget.stubs(:find_or_bootstrap).returns(mock_budget)
    BudgetAlertHistory.stubs(:cleanup_old_records!)

    # First call - not already sent
    BudgetAlertHistory.stubs(:already_sent?).returns(false)
    BudgetAlertHistory.stubs(:record_alert!)

    # Ensure user has budget emails enabled
    @user.update_budget_email_preferences("enabled" => true, "exceeded_alerts" => true)

    # First run should send email
    assert_enqueued_emails 1 do
      BudgetAlertJob.perform_now(@family.id)
    end

    # Second call - already sent
    BudgetAlertHistory.stubs(:already_sent?).returns(true)

    # Second run should not send duplicate
    assert_no_enqueued_emails do
      BudgetAlertJob.perform_now(@family.id)
    end
  end

  test "job respects warning threshold preference" do
    budget_category_at_85 = stub(
      id: SecureRandom.uuid,
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
    BudgetAlertHistory.stubs(:cleanup_old_records!)

    # Set threshold to 90% - shouldn't send email for 85% category
    @user.update_budget_email_preferences(
      "enabled" => true,
      "warning_alerts" => true,
      "warning_threshold" => 90
    )

    assert_no_enqueued_emails do
      BudgetAlertJob.perform_now(@family.id)
    end
  end

  # Integration tests with real database objects
  test "integration: sends exceeded email for real over-budget category" do
    # Ensure user has budget emails enabled
    @user.update!(preferences: {})
    @user.update_budget_email_preferences("enabled" => true, "exceeded_alerts" => true)

    # Get the real budget and sync categories
    budget = Budget.find_or_bootstrap(@family, start_date: Date.current)
    budget.sync_budget_categories

    # Find or create a budget category with real spending data
    category = categories(:food_and_drink)
    budget_category = budget.budget_categories.find_by(category: category)

    # Set a low budget that will be exceeded
    budget_category.update!(budgeted_spending: 10, currency: @family.currency)

    # Stub actual_spending to simulate over-budget (since we may not have real transactions)
    BudgetCategory.any_instance.stubs(:actual_spending).returns(50)

    # Clean up any existing alert history for this test
    BudgetAlertHistory.where(user: @user, budget: budget).delete_all

    assert_enqueued_emails 1 do
      BudgetAlertJob.perform_now(@family.id)
    end

    # Verify alert was tracked in BudgetAlertHistory
    assert BudgetAlertHistory.exists?(
      user: @user,
      budget: budget,
      alert_type: "exceeded"
    )
  end

  test "integration: cleans up old budget alert history" do
    # Get the current budget
    budget = Budget.find_or_bootstrap(@family, start_date: Date.current)
    budget.sync_budget_categories
    budget_category = budget.budget_categories.first

    # Create an old alert history record for a different budget
    old_budget = Budget.find_or_bootstrap(@family, start_date: Date.current.prev_month)
    old_budget.sync_budget_categories
    old_category = old_budget.budget_categories.first

    old_record = BudgetAlertHistory.create!(
      user: @user,
      budget: old_budget,
      budget_category: old_category,
      alert_type: "exceeded"
    )

    # Stub to avoid sending emails
    BudgetCategory.any_instance.stubs(:over_budget?).returns(false)
    BudgetCategory.any_instance.stubs(:near_limit?).returns(false)

    BudgetAlertJob.perform_now(@family.id)

    # Verify old data was cleaned up
    assert_nil BudgetAlertHistory.find_by(id: old_record.id)
  end

  test "integration: full flow with multiple users in family" do
    # Ensure both users exist and have different preferences
    admin = users(:family_admin)
    member = users(:family_member)

    admin.update!(preferences: {})
    admin.update_budget_email_preferences("enabled" => true, "exceeded_alerts" => true)

    member.update!(preferences: {})
    member.update_budget_email_preferences("enabled" => false) # Disabled for member

    # Get budget and set up over-budget scenario
    budget = Budget.find_or_bootstrap(@family, start_date: Date.current)
    budget.sync_budget_categories

    category = categories(:food_and_drink)
    budget_category = budget.budget_categories.find_by(category: category)
    budget_category&.update!(budgeted_spending: 10, currency: @family.currency)

    BudgetCategory.any_instance.stubs(:actual_spending).returns(50)

    # Clean up any existing alert history for this test
    BudgetAlertHistory.where(budget: budget).delete_all

    # Should only send to admin (member has alerts disabled)
    assert_enqueued_emails 1 do
      BudgetAlertJob.perform_now(@family.id)
    end
  end
end
