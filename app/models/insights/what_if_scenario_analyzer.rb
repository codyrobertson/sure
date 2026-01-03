module Insights
  class WhatIfScenarioAnalyzer < BaseAnalyzer
    REDUCTION_PERCENTAGES = [ 10, 25, 50 ]

    private

    def perform_analysis
      {
        category_scenarios: build_category_scenarios,
        subscription_scenarios: build_subscription_scenarios,
        easy_wins: calculate_easy_wins,
        impact_summary: build_impact_summary,
        insights: generate_insights
      }
    end

    def build_category_scenarios
      # Get top spending categories
      category_spending = spending_by_category

      category_spending
        .sort_by { |_, amount| -amount }
        .first(5)
        .map do |category_id, current_amount|
          category = categories.find { |c| c.id == category_id }
          next unless category

          reductions = REDUCTION_PERCENTAGES.map do |percent|
            reduction = current_amount * (percent / 100.0)
            monthly_savings = reduction
            annual_savings = reduction * 12

            {
              percent: percent,
              monthly_savings: format_money(monthly_savings),
              annual_savings: format_money(annual_savings),
              new_amount: format_money(current_amount - reduction)
            }
          end

          {
            category: {
              id: category.id,
              name: category.name,
              color: category.color
            },
            current: format_money(current_amount),
            reductions: reductions
          }
        end.compact
    end

    def build_subscription_scenarios
      # Get active subscriptions (all recurring transactions are treated as monthly)
      recurring = family.recurring_transactions.active

      # Sort by amount descending (amount is always populated, expected_amount_avg is often nil)
      sorted = recurring.sort_by { |rt| -rt.amount.abs }

      sorted.first(10).map do |rt|
        # All recurring transactions are treated as monthly in this system
        # Use amount field (always populated) - expected_amount_avg is often nil
        monthly_cost = rt.amount.abs
        annual_cost = monthly_cost * 12

        # Calculate priority based on usage and cost
        priority = calculate_subscription_priority(rt)

        # Get display name
        display_name = rt.merchant&.name || rt.name || "Unknown"

        {
          recurring_transaction: {
            id: rt.id,
            name: display_name,
            category: nil  # RecurringTransaction doesn't have category
          },
          monthly_cost: format_money(monthly_cost),
          annual_cost: format_money(annual_cost),
          priority: priority,
          priority_label: priority_label(priority)
        }
      end.sort_by { |s| s[:priority] }
    end

    def calculate_easy_wins
      wins = []

      # Subscription cancellations
      build_subscription_scenarios.each do |sub|
        next unless sub[:priority] <= 2 # Low priority = easy to cancel

        wins << {
          type: :cancel_subscription,
          action: "Cancel #{sub[:recurring_transaction][:name]}",
          monthly_savings: sub[:monthly_cost],
          annual_savings: sub[:annual_cost],
          difficulty: :easy
        }
      end

      # Category reductions (10% cuts on top categories)
      build_category_scenarios.first(3).each do |cat|
        reduction = cat[:reductions].first # 10% reduction

        wins << {
          type: :reduce_category,
          action: "Reduce #{cat[:category][:name]} by 10%",
          monthly_savings: reduction[:monthly_savings],
          annual_savings: reduction[:annual_savings],
          difficulty: :moderate
        }
      end

      # Sort by annual impact
      wins = wins.sort_by { |w| -w[:annual_savings][:amount] }

      total_monthly = wins.sum { |w| w[:monthly_savings][:amount] }
      total_annual = wins.sum { |w| w[:annual_savings][:amount] }

      {
        actions: wins.first(6),
        total_monthly_savings: format_money(total_monthly),
        total_annual_savings: format_money(total_annual),
        savings_rate_impact: calculate_savings_rate_impact(total_monthly)
      }
    end

    def build_impact_summary
      # Calculate how different scenarios affect savings rate
      current_income = income_for_period
      current_expenses = expenses_for_period
      current_rate = current_income.positive? ? ((current_income - current_expenses) / current_income * 100).round(1) : 0

      scenarios = [
        {
          name: "Current",
          monthly_savings: format_money(current_income - current_expenses),
          savings_rate: current_rate
        }
      ]

      # 10% expense reduction
      reduced_10 = current_expenses * 0.9
      rate_10 = current_income.positive? ? ((current_income - reduced_10) / current_income * 100).round(1) : 0
      scenarios << {
        name: "10% expense cut",
        monthly_savings: format_money(current_income - reduced_10),
        savings_rate: rate_10
      }

      # Cancel low-priority subscriptions
      sub_savings = build_subscription_scenarios
        .select { |s| s[:priority] <= 2 }
        .sum { |s| s[:monthly_cost][:amount] }

      if sub_savings > 0
        reduced_subs = current_expenses - sub_savings
        rate_subs = current_income.positive? ? ((current_income - reduced_subs) / current_income * 100).round(1) : 0
        scenarios << {
          name: "Cancel low-use subscriptions",
          monthly_savings: format_money(current_income - reduced_subs),
          savings_rate: rate_subs
        }
      end

      # Easy wins combined
      easy_wins = calculate_easy_wins
      if easy_wins[:total_monthly_savings][:amount] > 0
        reduced_easy = current_expenses - easy_wins[:total_monthly_savings][:amount]
        rate_easy = current_income.positive? ? ((current_income - reduced_easy) / current_income * 100).round(1) : 0
        scenarios << {
          name: "All easy wins",
          monthly_savings: format_money(current_income - reduced_easy),
          savings_rate: rate_easy
        }
      end

      scenarios
    end

    def generate_insights
      insights = []
      easy_wins = calculate_easy_wins

      # Easy wins summary
      if easy_wins[:actions].any?
        insights << build_insight(
          type: :easy_wins_available,
          message: "#{easy_wins[:actions].count} easy changes could save you #{easy_wins[:total_monthly_savings][:formatted]}/month (#{easy_wins[:total_annual_savings][:formatted]}/year).",
          severity: :positive
        )
      end

      # Savings rate boost
      if easy_wins[:savings_rate_impact] > 0
        insights << build_insight(
          type: :savings_rate_boost,
          message: "These changes could boost your savings rate by #{easy_wins[:savings_rate_impact]}%.",
          severity: :info
        )
      end

      # Top category opportunity
      top_category = build_category_scenarios.first
      if top_category
        reduction = top_category[:reductions].find { |r| r[:percent] == 25 }
        if reduction
          insights << build_insight(
            type: :category_opportunity,
            message: "Cutting #{top_category[:category][:name]} by 25% would save #{reduction[:annual_savings][:formatted]}/year.",
            severity: :info
          )
        end
      end

      insights
    end

    # Helpers

    def spending_by_category
      result = {}

      expense_transactions.each do |transaction|
        next unless transaction.category_id

        result[transaction.category_id] ||= 0
        result[transaction.category_id] += transaction.entry.amount.abs
      end

      result
    end

    def calculate_subscription_priority(recurring_transaction)
      # Priority 1-5, lower = easier to cancel
      # Based on: usage frequency, essential vs optional, cost

      # Get the display name for pattern matching
      display_name = (recurring_transaction.merchant&.name || recurring_transaction.name || "").downcase
      amount = recurring_transaction.amount.abs

      # Essential services get higher priority (harder to cancel)
      if display_name.include?("electric") || display_name.include?("water") ||
         display_name.include?("internet") || display_name.include?("utility") ||
         display_name.include?("insurance") || display_name.include?("rent") ||
         display_name.include?("mortgage")
        return 5
      end

      # Streaming/entertainment are easier to cancel
      if display_name.include?("netflix") || display_name.include?("spotify") ||
         display_name.include?("hulu") || display_name.include?("disney") ||
         display_name.include?("streaming") || display_name.include?("entertainment")
        return amount > 20 ? 2 : 1
      end

      # Check recent usage via last_occurrence_date
      last_date = recurring_transaction.last_occurrence_date
      days_since_use = last_date ? (Date.current - last_date).to_i : 999

      if days_since_use > 60
        1 # Not used in 2 months = easy to cancel
      elsif days_since_use > 30
        2
      else
        3
      end
    end

    def priority_label(priority)
      case priority
      when 1
        "Consider canceling"
      when 2
        "Low usage"
      when 3
        "Moderate use"
      when 4
        "Regular use"
      else
        "Essential"
      end
    end

    def calculate_savings_rate_impact(monthly_savings)
      current_income = income_for_period
      return 0 if current_income.zero?

      (monthly_savings / current_income * 100).round(1)
    end

    def income_for_period
      income_entries.sum { |entry| entry.amount.abs }
    end

    def expenses_for_period
      expense_entries.sum { |entry| entry.amount.abs }
    end
  end
end
