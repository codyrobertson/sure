require "test_helper"

class BudgetTest < ActiveSupport::TestCase
  setup do
    @family = families(:empty)
  end

  test "budget_date_valid? allows going back 2 years even without entries" do
    two_years_ago = 2.years.ago.beginning_of_month
    assert Budget.budget_date_valid?(two_years_ago, family: @family)
  end

  test "budget_date_valid? allows going back to earliest entry date if more than 2 years ago" do
    # Create an entry 3 years ago
    old_account = Account.create!(
      family: @family,
      accountable: Depository.new,
      name: "Old Account",
      status: "active",
      currency: "USD",
      balance: 1000
    )

    old_entry = Entry.create!(
      account: old_account,
      entryable: Transaction.new(category: categories(:income)),
      date: 3.years.ago,
      name: "Old Transaction",
      amount: 100,
      currency: "USD"
    )

    # Should allow going back to the old entry date
    assert Budget.budget_date_valid?(3.years.ago.beginning_of_month, family: @family)
  end

  test "budget_date_valid? does not allow dates before earliest entry or 2 years ago" do
    # Create an entry 1 year ago
    account = Account.create!(
      family: @family,
      accountable: Depository.new,
      name: "Test Account",
      status: "active",
      currency: "USD",
      balance: 500
    )

    Entry.create!(
      account: account,
      entryable: Transaction.new(category: categories(:income)),
      date: 1.year.ago,
      name: "Recent Transaction",
      amount: 100,
      currency: "USD"
    )

    # Should not allow going back more than 2 years
    refute Budget.budget_date_valid?(3.years.ago.beginning_of_month, family: @family)
  end

  test "budget_date_valid? does not allow future dates beyond current month" do
    refute Budget.budget_date_valid?(2.months.from_now, family: @family)
  end

  test "previous_budget_param returns nil when date is too old" do
    # Create a budget at the oldest allowed date
    two_years_ago = 2.years.ago.beginning_of_month
    budget = Budget.create!(
      family: @family,
      start_date: two_years_ago,
      end_date: two_years_ago.end_of_month,
      currency: "USD"
    )

    assert_nil budget.previous_budget_param
  end

  test "previous_budget_param returns param when date is valid" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: "USD"
    )

    assert_not_nil budget.previous_budget_param
  end

  # =============================================================================
  # Projection & Pacing Tests
  # =============================================================================

  test "days_remaining returns positive value for current month budget" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: "USD"
    )

    assert budget.days_remaining > 0
    assert budget.days_remaining <= budget.total_days
  end

  test "days_remaining returns 0 for past month budget" do
    last_month = 1.month.ago
    budget = Budget.create!(
      family: @family,
      start_date: last_month.beginning_of_month,
      end_date: last_month.end_of_month,
      currency: "USD"
    )

    assert_equal 0, budget.days_remaining
  end

  test "total_days calculates correct number of days in budget period" do
    # January has 31 days
    budget = Budget.create!(
      family: @family,
      start_date: Date.new(2025, 1, 1),
      end_date: Date.new(2025, 1, 31),
      currency: "USD"
    )

    assert_equal 31, budget.total_days
  end

  test "days_elapsed returns total_days for past budgets" do
    last_month = 1.month.ago
    budget = Budget.create!(
      family: @family,
      start_date: last_month.beginning_of_month,
      end_date: last_month.end_of_month,
      currency: "USD"
    )

    assert_equal budget.total_days, budget.days_elapsed
  end

  test "days_elapsed plus days_remaining equals total_days for current budget" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: "USD"
    )

    # days_elapsed includes today, days_remaining includes today
    # So total = days_elapsed + days_remaining - 1 (today counted twice)
    assert_equal budget.total_days, budget.days_elapsed + budget.days_remaining - 1
  end

  test "daily_pace calculates correct spending rate" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.new(2025, 1, 1),
      end_date: Date.new(2025, 1, 31),
      budgeted_spending: 3100,
      currency: "USD"
    )

    assert_equal 100.0, budget.daily_pace
  end

  test "daily_pace returns 0 when no budget set" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: "USD"
    )

    assert_equal 0, budget.daily_pace
  end

  test "monthly_pace scales daily pace to average month" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.new(2025, 1, 1),
      end_date: Date.new(2025, 1, 31),
      budgeted_spending: 3100,
      currency: "USD"
    )

    # daily_pace is 100, monthly_pace should be 100 * 30.44
    assert_in_delta 3044.0, budget.monthly_pace, 0.01
  end

  test "projected_spending returns actual_spending for past budgets" do
    last_month = 1.month.ago
    budget = Budget.create!(
      family: @family,
      start_date: last_month.beginning_of_month,
      end_date: last_month.end_of_month,
      budgeted_spending: 1000,
      currency: "USD"
    )

    # For past budgets, projected should equal actual
    assert_equal budget.actual_spending, budget.projected_spending
  end

  test "projected_variance is positive when over budget" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      budgeted_spending: 100,
      currency: "USD"
    )

    # Stub actual_spending to simulate overspending
    budget.stub :actual_spending, 200 do
      budget.stub :days_elapsed, 15 do
        budget.stub :total_days, 30 do
          # Actual daily pace = 200/15 = 13.33
          # Projected = 13.33 * 30 = 400
          # Variance = 400 - 100 = 300
          assert budget.projected_variance > 0
        end
      end
    end
  end

  test "projected_variance is negative when under budget" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      budgeted_spending: 1000,
      currency: "USD"
    )

    # Stub actual_spending to simulate underspending
    budget.stub :actual_spending, 100 do
      budget.stub :days_elapsed, 15 do
        budget.stub :total_days, 30 do
          budget.stub :current?, true do
            # Actual daily pace = 100/15 = 6.67
            # Projected = 6.67 * 30 = 200
            # Variance = 200 - 1000 = -800
            assert budget.projected_variance < 0
          end
        end
      end
    end
  end

  test "pace_status returns :on_track when within tolerance" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      budgeted_spending: 1000,
      currency: "USD"
    )

    # Stub to be exactly on pace (0% variance)
    budget.stub :projected_variance_percent, 0 do
      assert_equal :on_track, budget.pace_status
    end
  end

  test "pace_status returns :over when projected to exceed budget by more than 5%" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      budgeted_spending: 1000,
      currency: "USD"
    )

    budget.stub :projected_variance_percent, 10 do
      assert_equal :over, budget.pace_status
    end
  end

  test "pace_status returns :under when projected to be under budget by more than 5%" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      budgeted_spending: 1000,
      currency: "USD"
    )

    budget.stub :projected_variance_percent, -10 do
      assert_equal :under, budget.pace_status
    end
  end

  test "pace_status returns :on_track when budget not initialized" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: "USD"
    )

    assert_equal :on_track, budget.pace_status
  end

  test "suggested_daily_spending returns nil for past budgets" do
    last_month = 1.month.ago
    budget = Budget.create!(
      family: @family,
      start_date: last_month.beginning_of_month,
      end_date: last_month.end_of_month,
      budgeted_spending: 1000,
      currency: "USD"
    )

    assert_nil budget.suggested_daily_spending
  end

  test "suggested_daily_spending returns nil when over budget" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      budgeted_spending: 100,
      currency: "USD"
    )

    budget.stub :available_to_spend, -50 do
      assert_nil budget.suggested_daily_spending
    end
  end

  test "suggested_daily_spending returns Money object for current budget with remaining amount" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      budgeted_spending: 1000,
      currency: "USD"
    )

    budget.stub :available_to_spend, 500 do
      result = budget.suggested_daily_spending
      assert_not_nil result
      assert_instance_of Money, result
    end
  end

  test "actual_daily_pace returns 0 when no days elapsed" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: "USD"
    )

    budget.stub :days_elapsed, 0 do
      assert_equal 0, budget.actual_daily_pace
    end
  end

  test "projected_variance_percent returns 0 when no budget set" do
    budget = Budget.create!(
      family: @family,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: "USD"
    )

    assert_equal 0, budget.projected_variance_percent
  end
end
