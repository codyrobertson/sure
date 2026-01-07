require "test_helper"

class BudgetAlertMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:family_admin)
    @family = families(:dylan_family)
    @budget = budgets(:one)
  end

  test "budget_exceeded sends email with over-budget categories" do
    # Create a mock budget category that's over budget
    category = categories(:food_and_drink)
    budget_category = BudgetCategory.new(
      id: SecureRandom.uuid,
      budget: @budget,
      category: category,
      budgeted_spending: 100,
      currency: "USD"
    )

    # Stub actual_spending to return more than budgeted
    budget_category.stubs(:actual_spending).returns(150)
    budget_category.stubs(:actual_spending_money).returns(Money.new(150, "USD"))
    budget_category.stubs(:budgeted_spending_money).returns(Money.new(100, "USD"))
    budget_category.stubs(:available_to_spend_money).returns(Money.new(-50, "USD"))

    email = BudgetAlertMailer.with(
      user: @user,
      budget: @budget,
      over_budget_categories: [budget_category]
    ).budget_exceeded

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [@user.email], email.to
    assert_includes email.subject, "Budget categories exceeded"
  end

  test "budget_warning sends email with near-limit categories" do
    category = categories(:food_and_drink)
    budget_category = BudgetCategory.new(
      id: SecureRandom.uuid,
      budget: @budget,
      category: category,
      budgeted_spending: 100,
      currency: "USD"
    )

    # Stub to appear at 95% of budget
    budget_category.stubs(:actual_spending).returns(95)
    budget_category.stubs(:actual_spending_money).returns(Money.new(95, "USD"))
    budget_category.stubs(:budgeted_spending_money).returns(Money.new(100, "USD"))
    budget_category.stubs(:available_to_spend_money).returns(Money.new(5, "USD"))
    budget_category.stubs(:percent_of_budget_spent).returns(95)

    email = BudgetAlertMailer.with(
      user: @user,
      budget: @budget,
      near_limit_categories: [budget_category]
    ).budget_warning

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [@user.email], email.to
    assert_includes email.subject, "Budget categories nearing limit"
  end
end
