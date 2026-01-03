module Insights
  class CashFlowTimingAnalyzer < BaseAnalyzer
    PROJECTION_DAYS = 30
    LOW_BALANCE_THRESHOLD_PERCENT = 10  # 10% of average balance

    private

    def perform_analysis
      {
        balance_projection: build_balance_projection,
        upcoming_bills: find_upcoming_bills,
        income_timing: analyze_income_timing,
        alerts: generate_alerts,
        daily_summary: build_daily_summary,
        insights: generate_insights
      }
    end

    def build_balance_projection
      checking_accounts = family.accounts.active.where(accountable_type: "Depository")
      return [] if checking_accounts.empty?

      current_balance = checking_accounts.sum { |a| a.balance || 0 }
      upcoming_bills = find_upcoming_bills_raw
      expected_income = estimate_upcoming_income

      projections = []
      running_balance = current_balance

      (0..PROJECTION_DAYS).each do |day|
        date = Date.current + day.days

        # Calculate inflows for this day
        inflows = expected_income
          .select { |i| i[:date] == date }
          .sum { |i| i[:amount] }

        # Calculate outflows for this day
        outflows = upcoming_bills
          .select { |b| b[:date] == date }
          .sum { |b| b[:amount] }

        running_balance += inflows - outflows

        projections << {
          date: date.to_s,
          projected_balance: format_money(running_balance),
          inflows: format_money(inflows),
          outflows: format_money(outflows),
          is_low: running_balance < low_balance_threshold(current_balance)
        }
      end

      projections
    end

    def find_upcoming_bills
      find_upcoming_bills_raw.map do |bill|
        balance = current_checking_balance
        can_afford = balance >= bill[:amount]

        {
          name: bill[:name],
          date: bill[:date].to_s,
          days_until: (bill[:date] - Date.current).to_i,
          amount: format_money(bill[:amount]),
          category: bill[:category],
          can_afford: can_afford
        }
      end.sort_by { |b| b[:days_until] }.first(10)
    end

    def analyze_income_timing
      # Look for recurring income patterns
      income_transactions = family.entries
        .where(date: 3.months.ago..Date.current)
        .where(entryable_type: "Transaction")
        .where("amount < 0") # Income is negative
        .includes(:entryable)
        .order(date: :desc)

      # Find paycheck patterns (large recurring deposits)
      paychecks = income_transactions
        .group_by { |e| e.date.day }
        .select { |_, entries| entries.count >= 2 } # At least 2 occurrences
        .map do |day, entries|
          avg_amount = entries.sum { |e| e.amount.abs } / entries.count
          next if avg_amount < 500 # Filter small recurring amounts

          {
            day_of_month: day,
            avg_amount: avg_amount,
            occurrences: entries.count
          }
        end.compact

      return nil if paychecks.empty?

      # Find next expected paycheck
      most_likely = paychecks.max_by { |p| p[:avg_amount] }
      next_date = calculate_next_occurrence(most_likely[:day_of_month])

      {
        next_paycheck_date: next_date.to_s,
        amount: format_money(most_likely[:avg_amount]),
        days_until: (next_date - Date.current).to_i,
        frequency: detect_pay_frequency(paychecks)
      }
    end

    def generate_alerts
      alerts = []
      projection = build_balance_projection

      # Find dates where balance goes low
      low_balance_dates = projection.select { |p| p[:is_low] }
      if low_balance_dates.any?
        first_low = low_balance_dates.first
        alerts << {
          type: :low_balance,
          severity: :warning,
          message: "Balance may drop to #{first_low[:projected_balance][:formatted]} on #{first_low[:date]}",
          date: first_low[:date]
        }
      end

      # Bills we can't afford
      unaffordable = find_upcoming_bills.reject { |b| b[:can_afford] }
      unaffordable.each do |bill|
        alerts << {
          type: :cant_afford_bill,
          severity: :alert,
          message: "May not have enough to cover #{bill[:name]} (#{bill[:amount][:formatted]}) on #{bill[:date]}",
          date: bill[:date]
        }
      end

      # Large upcoming expense
      large_bills = find_upcoming_bills.select { |b| b[:amount][:amount] > 500 }
      large_bills.first(2).each do |bill|
        if bill[:days_until] <= 7
          alerts << {
            type: :large_expense_soon,
            severity: :info,
            message: "#{bill[:name]} (#{bill[:amount][:formatted]}) due in #{bill[:days_until]} days",
            date: bill[:date]
          }
        end
      end

      alerts.sort_by { |a| a[:date] }
    end

    def build_daily_summary
      projection = build_balance_projection.first(14) # 2 weeks

      # Group by week
      projection.group_by { |p| Date.parse(p[:date]).cweek }.map do |week, days|
        total_inflows = days.sum { |d| d[:inflows][:amount] }
        total_outflows = days.sum { |d| d[:outflows][:amount] }

        {
          week: week,
          start_date: days.first[:date],
          end_date: days.last[:date],
          starting_balance: days.first[:projected_balance],
          ending_balance: days.last[:projected_balance],
          total_inflows: format_money(total_inflows),
          total_outflows: format_money(total_outflows),
          net: format_money(total_inflows - total_outflows)
        }
      end
    end

    def generate_insights
      insights = []
      bills = find_upcoming_bills
      income = analyze_income_timing
      projection = build_balance_projection

      # Income timing insight
      if income
        insights << build_insight(
          type: :next_income,
          message: "Next expected income of #{income[:amount][:formatted]} in #{income[:days_until]} days.",
          severity: :info
        )
      end

      # Bill concentration warning
      bills_next_week = bills.select { |b| b[:days_until] <= 7 }
      if bills_next_week.length >= 3
        total = bills_next_week.sum { |b| b[:amount][:amount] }
        insights << build_insight(
          type: :bill_concentration,
          message: "#{bills_next_week.length} bills totaling #{format_money(total)[:formatted]} due in the next 7 days.",
          severity: :warning
        )
      end

      # Balance trend
      if projection.length >= 2
        start_balance = projection.first[:projected_balance][:amount]
        end_balance = projection.last[:projected_balance][:amount]

        if end_balance < start_balance * 0.5
          insights << build_insight(
            type: :declining_balance,
            message: "Your balance may drop significantly over the next #{PROJECTION_DAYS} days.",
            severity: :warning
          )
        elsif end_balance > start_balance * 1.2
          insights << build_insight(
            type: :growing_balance,
            message: "Your balance is projected to grow by #{((end_balance / start_balance - 1) * 100).round}% this month.",
            severity: :positive
          )
        end
      end

      insights
    end

    # Helpers

    def find_upcoming_bills_raw
      bills = []
      end_date = Date.current + PROJECTION_DAYS.days

      family.recurring_transactions.active.each do |rt|
        next_date = rt.next_expected_date
        next unless next_date && next_date <= end_date && next_date >= Date.current

        # Get display name from merchant or name attribute
        display_name = rt.merchant&.name || rt.name || "Unknown"
        # Use amount field (always populated) - expected_amount_avg is often nil
        amount = rt.amount.abs

        bills << {
          name: display_name,
          date: next_date,
          amount: amount,
          category: nil  # RecurringTransaction doesn't have category
        }
      end

      bills.sort_by { |b| b[:date] }
    end

    def estimate_upcoming_income
      income = []
      timing = analyze_income_timing
      return income unless timing

      # Add expected paychecks
      next_date = Date.parse(timing[:next_paycheck_date])
      end_date = Date.current + PROJECTION_DAYS.days

      while next_date <= end_date
        income << {
          date: next_date,
          amount: timing[:amount][:amount]
        }

        # Move to next occurrence based on frequency
        next_date = case timing[:frequency]
        when :weekly
          next_date + 7.days
        when :biweekly
          next_date + 14.days
        when :semimonthly
          next_date + 15.days
        else
          next_date + 1.month
        end
      end

      income
    end

    def current_checking_balance
      family.accounts.active
        .where(accountable_type: "Depository")
        .sum { |a| a.balance || 0 }
    end

    def low_balance_threshold(current_balance)
      [ current_balance * (LOW_BALANCE_THRESHOLD_PERCENT / 100.0), 100 ].max
    end

    def calculate_next_occurrence(day_of_month)
      this_month = Date.new(Date.current.year, Date.current.month, [ day_of_month, Date.current.end_of_month.day ].min)

      if this_month > Date.current
        this_month
      else
        next_month = Date.current.next_month
        Date.new(next_month.year, next_month.month, [ day_of_month, next_month.end_of_month.day ].min)
      end
    end

    def detect_pay_frequency(paychecks)
      return :monthly if paychecks.length == 1

      days = paychecks.map { |p| p[:day_of_month] }.sort

      if days.length == 2
        gap = days[1] - days[0]
        if gap.between?(13, 16)
          :semimonthly
        elsif gap.between?(6, 8)
          :biweekly
        else
          :monthly
        end
      else
        :monthly
      end
    end
  end
end
