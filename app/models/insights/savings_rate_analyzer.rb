module Insights
  class SavingsRateAnalyzer < BaseAnalyzer
    DEFAULT_TARGET_RATE = 20  # 20% savings rate target

    private

    def perform_analysis
      {
        current_rate: calculate_current_rate,
        historical_rates: calculate_historical_rates,
        trend: calculate_trend_direction,
        target: build_target_comparison,
        best_month: find_best_month,
        worst_month: find_worst_month,
        insights: generate_insights
      }
    end

    def calculate_current_rate
      income = income_for_period(period)
      expenses = expenses_for_period(period)
      savings = income - expenses

      rate = income.positive? ? ((savings / income) * 100).round(1) : 0

      {
        percent: rate,
        income: format_money(income),
        expenses: format_money(expenses),
        savings: format_money(savings)
      }
    end

    def calculate_historical_rates
      # Get last 12 months of savings rates
      monthly_periods(months_back: 12).map do |p|
        income = income_for_period(p)
        expenses = expenses_for_period(p)
        savings = income - expenses
        rate = income.positive? ? ((savings / income) * 100).round(1) : 0

        {
          month: p.start_date.strftime("%b %Y"),
          month_short: p.start_date.strftime("%b"),
          rate: rate,
          income: format_money(income),
          expenses: format_money(expenses),
          savings: format_money(savings)
        }
      end
    end

    def calculate_trend_direction
      rates = calculate_historical_rates.map { |r| r[:rate] }
      return { direction: :stable, change_percent: 0, improving: nil } if rates.length < 3

      # Compare recent 3 months average to prior 3 months average
      recent = rates.last(3).sum / 3.0
      prior = rates.first(3).sum / 3.0

      return { direction: :stable, change_percent: 0, improving: nil } if prior.zero?

      change = ((recent - prior) / prior.abs * 100).round(1)

      direction = if change > 10
        :up
      elsif change < -10
        :down
      else
        :stable
      end

      {
        direction: direction,
        change_percent: change.abs,
        improving: change > 0
      }
    end

    def build_target_comparison
      current = calculate_current_rate
      target_rate = DEFAULT_TARGET_RATE
      gap = target_rate - current[:percent]

      # Calculate how much more needs to be saved monthly to hit target
      income = current[:income][:amount]
      current_savings = current[:savings][:amount]
      target_savings = income * (target_rate / 100.0)
      monthly_gap = target_savings - current_savings

      {
        rate: target_rate,
        gap: gap.round(1),
        on_target: current[:percent] >= target_rate,
        monthly_savings_needed: format_money([ monthly_gap, 0 ].max)
      }
    end

    def find_best_month
      rates = calculate_historical_rates
      return nil if rates.empty?

      best = rates.max_by { |r| r[:rate] }
      {
        month: best[:month],
        rate: best[:rate],
        savings: best[:savings]
      }
    end

    def find_worst_month
      rates = calculate_historical_rates
      return nil if rates.empty?

      worst = rates.min_by { |r| r[:rate] }
      {
        month: worst[:month],
        rate: worst[:rate],
        savings: worst[:savings]
      }
    end

    def generate_insights
      insights = []
      current = calculate_current_rate
      target = build_target_comparison
      trend = calculate_trend_direction

      # Target achievement
      if target[:on_target]
        insights << build_insight(
          type: :target_achieved,
          message: "You're meeting your #{target[:rate]}% savings goal! Keep it up.",
          severity: :positive
        )
      elsif target[:gap] > 0 && target[:gap] <= 5
        insights << build_insight(
          type: :close_to_target,
          message: "You're #{target[:gap]}% away from your savings goal. Small adjustments could get you there.",
          severity: :info
        )
      elsif target[:gap] > 5
        insights << build_insight(
          type: :below_target,
          message: "Save #{target[:monthly_savings_needed][:formatted]} more per month to hit your #{target[:rate]}% goal.",
          severity: :warning
        )
      end

      # Negative savings rate
      if current[:percent] < 0
        insights << build_insight(
          type: :negative_savings,
          message: "You're spending more than you earn. Your expenses exceeded income by #{current[:savings][:formatted].gsub('-', '')}.",
          severity: :alert
        )
      end

      # Trend feedback
      if trend[:improving] == true
        insights << build_insight(
          type: :improving_trend,
          message: "Your savings rate has improved by #{trend[:change_percent]}% recently. Great progress!",
          severity: :positive
        )
      elsif trend[:improving] == false && trend[:change_percent] > 15
        insights << build_insight(
          type: :declining_trend,
          message: "Your savings rate has dropped #{trend[:change_percent]}% compared to earlier months.",
          severity: :warning
        )
      end

      insights
    end

    # Helpers

    def income_for_period(p)
      total = 0

      entries_for_period(p).where(entryable_type: "Transaction").each do |entry|
        transaction = entry.entryable
        next if excluded_from_totals?(transaction)

        category = transaction.category
        is_income = if category&.classification.present?
          category.classification == "income"
        else
          entry.amount.negative? # Fallback to amount sign
        end

        total += entry.amount.abs if is_income
      end

      total
    end

    def expenses_for_period(p)
      total = 0

      entries_for_period(p).where(entryable_type: "Transaction").each do |entry|
        transaction = entry.entryable
        next if excluded_from_totals?(transaction)

        category = transaction.category
        is_expense = if category&.classification.present?
          category.classification == "expense"
        else
          entry.amount.positive? # Fallback to amount sign
        end

        total += entry.amount.abs if is_expense
      end

      total
    end
  end
end
