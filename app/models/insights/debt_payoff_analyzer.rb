module Insights
  class DebtPayoffAnalyzer < BaseAnalyzer
    ACCELERATION_SCENARIOS = [ 50, 100, 200, 500 ]

    private

    def perform_analysis
      debt_accounts = find_debt_accounts
      return nil if debt_accounts.empty?

      {
        debts: analyze_debts(debt_accounts),
        total_debt: calculate_total_debt(debt_accounts),
        interest_this_period: calculate_interest_paid,
        principal_this_period: calculate_principal_paid,
        acceleration_scenarios: build_acceleration_scenarios(debt_accounts),
        progress: calculate_progress(debt_accounts),
        insights: generate_insights(debt_accounts)
      }
    end

    def find_debt_accounts
      # Find accounts with negative balances (debts) - credit cards, loans
      family.accounts.active.select do |account|
        account.accountable_type.in?(%w[CreditCard Loan]) ||
          (account.balance.present? && account.balance < 0)
      end
    end

    def analyze_debts(debt_accounts)
      debt_accounts.map do |account|
        balance = account.balance&.abs || 0
        next if balance.zero?

        interest_rate = extract_interest_rate(account)
        monthly_payment = calculate_average_monthly_payment(account)

        payoff_data = calculate_payoff_projection(balance, interest_rate, monthly_payment)

        {
          account: {
            id: account.id,
            name: account.name,
            type: account.accountable_type
          },
          balance: format_money(balance),
          interest_rate: interest_rate,
          monthly_payment: format_money(monthly_payment),
          payoff_date: payoff_data[:payoff_date],
          months_remaining: payoff_data[:months_remaining],
          total_interest: format_money(payoff_data[:total_interest]),
          percent_paid: calculate_percent_paid(account)
        }
      end.compact.sort_by { |d| -d[:balance][:amount] }
    end

    def calculate_total_debt(debt_accounts)
      total = debt_accounts.sum { |a| a.balance&.abs || 0 }
      format_money(total)
    end

    def calculate_interest_paid
      # Look for interest charges in the period
      # Interest charges appear on the credit card/loan accounts themselves
      interest_total = 0
      debt_account_ids = find_debt_accounts.map(&:id)

      # Search for interest charges on debt accounts
      family.entries
        .where(date: period.start_date..period.end_date)
        .where(account_id: debt_account_ids)
        .where(entryable_type: "Transaction")
        .where("amount > 0") # Interest charges are positive (increasing debt)
        .includes(:entryable)
        .each do |entry|
          transaction = entry.entryable
          name = (entry.name || transaction.merchant&.name || "").downcase

          # Expanded interest detection patterns
          is_interest = name.include?("interest") ||
                        name.include?("finance charge") ||
                        name.include?("fee") ||
                        name.include?("apr") ||
                        name.include?("periodic") ||
                        (transaction.category&.name&.downcase&.include?("interest") rescue false)

          interest_total += entry.amount.abs if is_interest
        end

      format_money(interest_total)
    end

    def calculate_principal_paid
      # Debt payments are recorded on SOURCE accounts (checking) with kind: cc_payment or loan_payment
      # NOT on the debt accounts themselves
      payments_total = 0

      # Find all cc_payment and loan_payment transactions in this period
      family.entries
        .where(date: period.start_date..period.end_date)
        .where(entryable_type: "Transaction")
        .includes(:entryable)
        .each do |entry|
          transaction = entry.entryable
          next unless transaction.kind.in?(%w[cc_payment loan_payment])

          # Payment amounts are positive on the source account (money going out)
          payments_total += entry.amount.abs if entry.amount.positive?
        end

      interest = calculate_interest_paid[:amount]
      principal = [ payments_total - interest, 0 ].max

      format_money(principal)
    end

    def calculate_progress(debt_accounts)
      interest = calculate_interest_paid[:amount]
      principal = calculate_principal_paid[:amount]
      total = interest + principal

      {
        principal_paid: format_money(principal),
        interest_paid: format_money(interest),
        total_paid: format_money(total),
        principal_percent: total.positive? ? ((principal / total) * 100).round(1) : 0
      }
    end

    def build_acceleration_scenarios(debt_accounts)
      total_balance = debt_accounts.sum { |a| a.balance&.abs || 0 }
      return [] if total_balance.zero?

      # Get weighted average interest rate
      weighted_rate = 0
      debt_accounts.each do |account|
        balance = account.balance&.abs || 0
        rate = extract_interest_rate(account)
        weighted_rate += (balance / total_balance) * rate if total_balance.positive?
      end

      # Current monthly payment total
      current_payment = debt_accounts.sum { |a| calculate_average_monthly_payment(a) }
      return [] if current_payment.zero?

      baseline = calculate_payoff_projection(total_balance, weighted_rate, current_payment)

      ACCELERATION_SCENARIOS.map do |extra|
        new_payment = current_payment + extra
        accelerated = calculate_payoff_projection(total_balance, weighted_rate, new_payment)

        months_saved = baseline[:months_remaining] - accelerated[:months_remaining]
        interest_saved = baseline[:total_interest] - accelerated[:total_interest]

        {
          extra_monthly: format_money(extra),
          new_payment: format_money(new_payment),
          months_saved: [ months_saved, 0 ].max,
          interest_saved: format_money([ interest_saved, 0 ].max),
          new_payoff_date: accelerated[:payoff_date]
        }
      end
    end

    def generate_insights(debt_accounts)
      insights = []
      return insights if debt_accounts.empty?

      total_debt = debt_accounts.sum { |a| a.balance&.abs || 0 }
      progress = calculate_progress(debt_accounts)

      # High interest warning
      high_rate_accounts = debt_accounts.select { |a| extract_interest_rate(a) > 20 }
      if high_rate_accounts.any?
        insights << build_insight(
          type: :high_interest,
          message: "#{high_rate_accounts.count} account(s) have interest rates above 20%. Consider prioritizing these.",
          severity: :warning
        )
      end

      # Principal vs interest ratio
      if progress[:principal_percent] < 50 && progress[:total_paid][:amount] > 0
        insights << build_insight(
          type: :interest_heavy,
          message: "#{(100 - progress[:principal_percent]).round}% of your payments are going to interest. Consider increasing payments.",
          severity: :warning
        )
      end

      # Good progress
      if progress[:principal_percent] >= 70
        insights << build_insight(
          type: :good_progress,
          message: "#{progress[:principal_percent].round}% of your payments are reducing principal. Great job!",
          severity: :positive
        )
      end

      # Small acceleration impact
      scenarios = build_acceleration_scenarios(debt_accounts)
      best_scenario = scenarios.find { |s| s[:months_saved] >= 6 }
      if best_scenario
        insights << build_insight(
          type: :acceleration_opportunity,
          message: "Adding #{best_scenario[:extra_monthly][:formatted]}/month could save you #{best_scenario[:interest_saved][:formatted]} in interest.",
          severity: :info
        )
      end

      insights
    end

    # Helpers

    def extract_interest_rate(account)
      # Try to get interest rate from account settings or default
      if account.respond_to?(:interest_rate) && account.interest_rate.present?
        account.interest_rate.to_f
      elsif account.accountable_type == "CreditCard"
        19.99 # Default credit card rate
      elsif account.accountable_type == "Loan"
        7.0 # Default loan rate
      else
        15.0 # Generic default
      end
    end

    def calculate_average_monthly_payment(account)
      # Look at last 3 months of payments to this account
      payments = family.entries
        .where(account_id: account.id)
        .where(entryable_type: "Transaction")
        .where(date: 3.months.ago..Date.current)
        .where("amount < 0") # Payments reduce the balance
        .sum(:amount)
        .abs

      payments / 3.0
    end

    def calculate_payoff_projection(balance, annual_rate, monthly_payment)
      return { months_remaining: 0, payoff_date: Date.current, total_interest: 0 } if balance.zero?
      return { months_remaining: 999, payoff_date: nil, total_interest: 0 } if monthly_payment.zero?

      monthly_rate = annual_rate / 100.0 / 12.0
      remaining = balance
      months = 0
      total_interest = 0
      max_months = 360 # 30 year cap

      while remaining > 0 && months < max_months
        interest = remaining * monthly_rate
        principal = [ monthly_payment - interest, remaining ].min

        # If payment doesn't cover interest, debt grows forever
        if monthly_payment <= interest
          return { months_remaining: 999, payoff_date: nil, total_interest: 0 }
        end

        remaining -= principal
        total_interest += interest
        months += 1
      end

      {
        months_remaining: months,
        payoff_date: Date.current + months.months,
        total_interest: total_interest
      }
    end

    def calculate_percent_paid(account)
      # Try to estimate how much of the original debt has been paid
      # Look at balance history if available
      balances = account.balances.order(date: :asc).limit(1).first
      original_balance = balances&.balance&.abs || account.balance&.abs || 0
      current_balance = account.balance&.abs || 0

      return 0 if original_balance.zero?

      paid = original_balance - current_balance
      percent = (paid / original_balance * 100).round(1)
      [ [ percent, 0 ].max, 100 ].min
    end
  end
end
