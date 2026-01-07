# Preview all emails at http://localhost:3000/rails/mailers/budget_alert_mailer
class BudgetAlertMailerPreview < ActionMailer::Preview
  def budget_exceeded
    user = User.first
    family = user.family
    budget = Budget.find_or_bootstrap(family, start_date: Date.current)

    # Find categories that are over budget, or create mock ones
    over_budget_categories = budget.budget_categories.select(&:over_budget?)

    # If no real over-budget categories, create mock data for preview
    if over_budget_categories.empty?
      over_budget_categories = [
        OpenStruct.new(
          name: "Food & Drink",
          budgeted_spending_money: Money.new(500, "USD"),
          actual_spending_money: Money.new(650, "USD"),
          available_to_spend_money: Money.new(-150, "USD")
        ),
        OpenStruct.new(
          name: "Entertainment",
          budgeted_spending_money: Money.new(200, "USD"),
          actual_spending_money: Money.new(275, "USD"),
          available_to_spend_money: Money.new(-75, "USD")
        )
      ]
    end

    BudgetAlertMailer.with(
      user: user,
      budget: budget,
      over_budget_categories: over_budget_categories
    ).budget_exceeded
  end

  def budget_warning
    user = User.first
    family = user.family
    budget = Budget.find_or_bootstrap(family, start_date: Date.current)

    # Find categories near limit, or create mock ones
    near_limit_categories = budget.budget_categories.select(&:near_limit?)

    # If no real near-limit categories, create mock data for preview
    if near_limit_categories.empty?
      near_limit_categories = [
        OpenStruct.new(
          name: "Groceries",
          budgeted_spending_money: Money.new(400, "USD"),
          actual_spending_money: Money.new(380, "USD"),
          available_to_spend_money: Money.new(20, "USD"),
          percent_of_budget_spent: 95
        ),
        OpenStruct.new(
          name: "Transportation",
          budgeted_spending_money: Money.new(300, "USD"),
          actual_spending_money: Money.new(275, "USD"),
          available_to_spend_money: Money.new(25, "USD"),
          percent_of_budget_spent: 92
        )
      ]
    end

    BudgetAlertMailer.with(
      user: user,
      budget: budget,
      near_limit_categories: near_limit_categories
    ).budget_warning
  end
end
