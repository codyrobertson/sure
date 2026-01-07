require "test_helper"

class GoalTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
  end

  # Validation tests
  test "valid goal with all required attributes" do
    goal = Goal.new(
      family: @family,
      account: @account,
      name: "Emergency Fund",
      target_amount: 10000,
      currency: @account.currency
    )
    assert goal.valid?
  end

  test "requires name" do
    goal = Goal.new(
      family: @family,
      account: @account,
      target_amount: 10000,
      currency: @account.currency
    )
    assert_not goal.valid?
    assert_includes goal.errors[:name], "can't be blank"
  end

  test "requires target_amount" do
    goal = Goal.new(
      family: @family,
      account: @account,
      name: "Test Goal",
      currency: @account.currency
    )
    assert_not goal.valid?
    assert_includes goal.errors[:target_amount], "can't be blank"
  end

  test "target_amount must be greater than zero" do
    goal = Goal.new(
      family: @family,
      account: @account,
      name: "Test Goal",
      target_amount: 0,
      currency: @account.currency
    )
    assert_not goal.valid?
    assert_includes goal.errors[:target_amount], "must be greater than 0"
  end

  test "currency must match account currency" do
    goal = Goal.new(
      family: @family,
      account: @account,
      name: "Test Goal",
      target_amount: 10000,
      currency: "EUR"  # Account uses USD
    )
    assert_not goal.valid?
    assert_includes goal.errors[:currency], "must match account currency"
  end

  test "account must belong to same family" do
    other_family = families(:empty)
    goal = Goal.new(
      family: other_family,
      account: @account,  # belongs to dylan_family
      name: "Test Goal",
      target_amount: 10000,
      currency: @account.currency
    )
    assert_not goal.valid?
    assert_includes goal.errors[:account], "must belong to the same family"
  end

  test "validates status enum values" do
    goal = build_goal
    goal.status = "active"
    assert goal.valid?

    goal.status = "completed"
    assert goal.valid?

    goal.status = "paused"
    assert goal.valid?

    goal.status = "cancelled"
    assert goal.valid?
  end

  # Progress calculation tests
  test "progress_percentage returns 0 when target is zero" do
    goal = build_goal(target_amount: 0.01)  # Use small amount since > 0 is required
    goal.stubs(:current_balance).returns(0)
    goal.target_amount = 0
    # Skip validation for this test
    assert_equal 0, goal.progress_percentage
  end

  test "progress_percentage returns 100 when balance exceeds target" do
    goal = build_goal(target_amount: 1000)
    goal.stubs(:current_balance).returns(1500)
    assert_equal 100, goal.progress_percentage
  end

  test "progress_percentage calculates correctly" do
    goal = build_goal(target_amount: 1000)
    goal.stubs(:current_balance).returns(250)
    assert_equal 25.0, goal.progress_percentage
  end

  # Remaining amount tests
  test "remaining_amount returns positive difference" do
    goal = build_goal(target_amount: 1000)
    goal.stubs(:current_balance).returns(400)
    assert_equal 600, goal.remaining_amount
  end

  test "remaining_amount returns 0 when balance exceeds target" do
    goal = build_goal(target_amount: 1000)
    goal.stubs(:current_balance).returns(1500)
    assert_equal 0, goal.remaining_amount
  end

  # On track tests
  test "on_track? returns true when no target date" do
    goal = build_goal(target_date: nil)
    assert goal.on_track?
  end

  test "on_track? returns true when target already reached" do
    goal = build_goal(target_amount: 1000, target_date: 30.days.from_now)
    goal.stubs(:current_balance).returns(1500)
    assert goal.on_track?
  end

  test "on_track? returns false when target date has passed" do
    goal = build_goal(target_amount: 1000, target_date: 1.day.ago)
    goal.stubs(:current_balance).returns(500)
    assert_not goal.on_track?
  end

  test "on_track? returns true with adequate savings rate" do
    goal = build_goal(target_amount: 1000, target_date: 100.days.from_now, starting_balance: 0)
    goal.stubs(:current_balance).returns(100)  # 100 saved, 900 remaining, 100 days = 9/day needed
    goal.stubs(:daily_savings_rate).returns(10.0)  # 10/day actual
    assert goal.on_track?
  end

  test "on_track? returns false with inadequate savings rate" do
    goal = build_goal(target_amount: 1000, target_date: 10.days.from_now, starting_balance: 0)
    goal.stubs(:current_balance).returns(100)  # 100 saved, 900 remaining, 10 days = 90/day needed
    goal.stubs(:daily_savings_rate).returns(5.0)  # 5/day actual
    assert_not goal.on_track?
  end

  # Days until target tests
  test "days_until_target returns nil when no target date" do
    goal = build_goal(target_date: nil)
    assert_nil goal.days_until_target
  end

  test "days_until_target returns positive days for future date" do
    goal = build_goal(target_date: 30.days.from_now.to_date)
    assert_equal 30, goal.days_until_target
  end

  test "days_until_target returns negative for past date" do
    goal = build_goal(target_date: 5.days.ago.to_date)
    assert_equal(-5, goal.days_until_target)
  end

  # Complete! tests
  test "complete! changes status to completed" do
    goal = create_goal
    goal.complete!
    assert_equal "completed", goal.status
  end

  # Scope tests
  test "in_progress scope returns active and paused goals" do
    active_goal = create_goal(status: "active")
    paused_goal = create_goal(status: "paused")
    completed_goal = create_goal(status: "completed")
    cancelled_goal = create_goal(status: "cancelled")

    in_progress = @family.goals.in_progress
    assert_includes in_progress, active_goal
    assert_includes in_progress, paused_goal
    assert_not_includes in_progress, completed_goal
    assert_not_includes in_progress, cancelled_goal
  end

  test "by_target_date orders nulls last" do
    goal_with_date = create_goal(target_date: 10.days.from_now)
    goal_without_date = create_goal(target_date: nil)
    goal_earlier = create_goal(target_date: 5.days.from_now)

    ordered = @family.goals.by_target_date
    assert_equal goal_earlier, ordered.first
    assert_equal goal_with_date, ordered.second
    assert_equal goal_without_date, ordered.last
  end

  # Daily savings rate tests
  test "daily_savings_rate returns 0 when created today" do
    goal = build_goal(starting_balance: 0)
    goal.created_at = Time.current
    goal.stubs(:current_balance).returns(100)
    assert_equal 0.0, goal.send(:daily_savings_rate)
  end

  test "daily_savings_rate calculates correctly" do
    goal = build_goal(starting_balance: 100)
    goal.created_at = 10.days.ago
    goal.stubs(:current_balance).returns(200)  # 100 progress over 10 days
    assert_in_delta 10.0, goal.send(:daily_savings_rate), 0.01
  end

  private

  def build_goal(attrs = {})
    Goal.new({
      family: @family,
      account: @account,
      name: "Test Goal",
      target_amount: 10000,
      currency: @account.currency,
      status: "active"
    }.merge(attrs))
  end

  def create_goal(attrs = {})
    goal = build_goal(attrs)
    goal.save!
    goal
  end
end
