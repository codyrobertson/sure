module Insights
  class RecurringCostAnalyzer < BaseAnalyzer
    UNUSED_THRESHOLD_DAYS = 45  # Days of inactivity to flag subscription

    private

    def perform_analysis
      {
        fixed_costs: analyze_fixed_costs,
        subscriptions: analyze_subscriptions,
        potentially_unused: find_potentially_unused,
        upcoming_bills: find_upcoming_bills,
        monthly_total: calculate_monthly_total,
        annual_total: calculate_annual_total,
        insights: generate_insights
      }
    end

    def analyze_fixed_costs
      # Get recurring transactions that are fixed costs (rent, mortgage, car payment, insurance)
      recurring = family.recurring_transactions.active

      fixed_items = recurring.select do |rt|
        item_name = display_name(rt).downcase
        is_fixed_cost?(item_name)
      end

      items = fixed_items.map do |rt|
        {
          id: rt.id,
          name: display_name(rt),
          amount: format_money(rt.amount.abs),
          frequency: "monthly",
          next_date: rt.next_expected_date
        }
      end

      {
        total: format_money(items.sum { |i| i[:amount][:amount] }),
        count: items.count,
        items: items.sort_by { |i| -i[:amount][:amount] }
      }
    end

    def analyze_subscriptions
      recurring = family.recurring_transactions.active

      subscription_items = recurring.select do |rt|
        item_name = display_name(rt).downcase
        is_subscription?(item_name)
      end

      items = subscription_items.map do |rt|
        # All recurring transactions are monthly in this system
        monthly_amount = rt.amount.abs

        {
          id: rt.id,
          name: display_name(rt),
          amount: format_money(rt.amount.abs),
          monthly_amount: format_money(monthly_amount),
          frequency: "monthly",
          next_date: rt.next_expected_date
        }
      end

      {
        total: format_money(items.sum { |i| i[:monthly_amount][:amount] }),
        count: items.count,
        items: items.sort_by { |i| -i[:monthly_amount][:amount] }
      }
    end

    def find_potentially_unused
      subscriptions = analyze_subscriptions[:items]
      unused = []

      subscriptions.each do |sub|
        recurring = family.recurring_transactions.find_by(id: sub[:id])
        next unless recurring

        # Check last occurrence date
        last_date = recurring.last_occurrence_date
        next unless last_date

        days_since = (Date.current - last_date).to_i

        if days_since >= UNUSED_THRESHOLD_DAYS
          unused << {
            recurring_transaction: sub,
            days_inactive: days_since,
            monthly_cost: sub[:monthly_amount],
            last_charge_date: last_date.to_s
          }
        end
      end

      unused.sort_by { |u| -u[:days_inactive] }
    end

    def find_upcoming_bills
      upcoming = []
      end_date = Date.current + 14.days

      family.recurring_transactions.active.each do |rt|
        next_date = rt.next_expected_date
        next unless next_date && next_date <= end_date && next_date >= Date.current

        upcoming << {
          name: display_name(rt),
          date: next_date.to_s,
          days_until: (next_date - Date.current).to_i,
          amount: format_money(rt.amount.abs)
        }
      end

      upcoming.sort_by { |u| u[:days_until] }
    end

    def calculate_monthly_total
      fixed = analyze_fixed_costs[:total][:amount]
      subs = analyze_subscriptions[:total][:amount]

      format_money(fixed + subs)
    end

    def calculate_annual_total
      monthly = calculate_monthly_total[:amount]
      format_money(monthly * 12)
    end

    def generate_insights
      insights = []

      # Subscription count warning
      subs = analyze_subscriptions
      if subs[:count] > 10
        insights << build_insight(
          type: :many_subscriptions,
          message: "You have #{subs[:count]} active subscriptions totaling #{subs[:total][:formatted]}/month.",
          severity: :info
        )
      end

      # Potentially unused subscriptions
      unused = find_potentially_unused
      if unused.any?
        total_unused = unused.sum { |u| u[:monthly_cost][:amount] }
        insights << build_insight(
          type: :unused_subscriptions,
          message: "#{unused.count} subscription(s) haven't been used in #{UNUSED_THRESHOLD_DAYS}+ days. Could save #{format_money(total_unused)[:formatted]}/month.",
          severity: :warning
        )
      end

      # High fixed costs as percentage of income
      monthly_total = calculate_monthly_total[:amount]
      income = income_for_period

      if income.positive?
        fixed_percent = (monthly_total / income * 100).round(1)
        if fixed_percent > 50
          insights << build_insight(
            type: :high_fixed_costs,
            message: "Fixed costs are #{fixed_percent}% of your income. Consider reducing where possible.",
            severity: :warning
          )
        elsif fixed_percent < 30
          insights << build_insight(
            type: :good_fixed_costs,
            message: "Your fixed costs are #{fixed_percent}% of income. Good financial flexibility!",
            severity: :positive
          )
        end
      end

      # Upcoming bills reminder
      upcoming = find_upcoming_bills.first(3)
      if upcoming.any?
        due_soon = upcoming.select { |u| u[:days_until] <= 3 }
        if due_soon.any?
          names = due_soon.map { |u| u[:name] }.join(", ")
          insights << build_insight(
            type: :bills_due_soon,
            message: "Bills due in the next 3 days: #{names}",
            severity: :info
          )
        end
      end

      insights
    end

    # Helpers

    def display_name(recurring_transaction)
      recurring_transaction.merchant&.name || recurring_transaction.name || "Unknown"
    end

    def is_fixed_cost?(name)
      fixed_keywords = %w[rent mortgage housing car auto insurance utility utilities electric gas water internet phone loan payment]
      fixed_keywords.any? { |kw| name.include?(kw) }
    end

    def is_subscription?(name)
      subscription_keywords = %w[subscription streaming netflix hulu disney spotify apple music amazon prime membership gym fitness]
      subscription_keywords.any? { |kw| name.include?(kw) }
    end

    def income_for_period
      total = 0

      transaction_entries.each do |entry|
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
  end
end
