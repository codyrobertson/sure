class Assistant::Function::GetRecurringTransactions < Assistant::Function
  class << self
    def name
      "get_recurring_transactions"
    end

    def description
      <<~INSTRUCTIONS
        Get the user's recurring transactions (bills, subscriptions, regular payments).

        This is essential for:
        - Understanding fixed monthly expenses (rent, mortgage, car payments, subscriptions)
        - Calculating actual monthly burn rate
        - Forecasting future expenses
        - Identifying upcoming bills

        Returns both active and inactive recurring patterns detected from transaction history.
        Each recurring transaction includes: name, amount, expected day of month, last/next occurrence dates.
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      properties: {
        status: {
          type: "string",
          enum: %w[active inactive all],
          description: "Filter by status: active (current bills), inactive (past bills), or all"
        },
        include_projected: {
          type: "boolean",
          description: "Include projected next occurrence for active recurring transactions"
        }
      },
      required: %w[status include_projected]
    )
  end

  def call(params = {})
    report_progress("Finding recurring transactions...")

    status_filter = params["status"] || "active"
    include_projected = params["include_projected"] != false

    recurring = case status_filter
    when "active"
      family.recurring_transactions.active
    when "inactive"
      family.recurring_transactions.inactive
    else
      family.recurring_transactions
    end

    recurring = recurring.includes(:merchant).order(amount: :desc)

    # Group by type (income vs expense based on amount sign)
    expenses = []
    income = []

    recurring.each do |rt|
      data = {
        id: rt.id,
        name: rt.merchant&.name || rt.name,
        amount: rt.amount.abs.to_f,
        currency: rt.currency,
        formatted_amount: rt.amount_money.abs.format,
        expected_day_of_month: rt.expected_day_of_month,
        last_occurrence_date: rt.last_occurrence_date,
        next_expected_date: rt.next_expected_date,
        occurrence_count: rt.occurrence_count,
        status: rt.status,
        is_manual: rt.manual?
      }

      # Add variance info if available
      if rt.has_amount_variance?
        data[:amount_range] = {
          min: rt.expected_amount_min.to_f,
          max: rt.expected_amount_max.to_f,
          avg: rt.expected_amount_avg.to_f
        }
      end

      # Add projected next occurrence
      if include_projected && rt.active? && rt.next_expected_date&.future?
        data[:projected_next] = {
          date: rt.next_expected_date,
          amount: (rt.expected_amount_avg || rt.amount).abs.to_f
        }
      end

      if rt.amount.negative?
        income << data
      else
        expenses << data
      end
    end

    # Calculate totals
    monthly_expense_total = expenses.sum { |e| e[:amount] }
    monthly_income_total = income.sum { |i| i[:amount] }

    # Get upcoming bills in the next 30 days
    upcoming_bills = expenses
      .select { |e| e[:next_expected_date] && e[:next_expected_date] <= 30.days.from_now.to_date }
      .sort_by { |e| e[:next_expected_date] }

    {
      recurring_expenses: expenses,
      recurring_income: income,
      summary: {
        total_monthly_recurring_expenses: monthly_expense_total.round(2),
        total_monthly_recurring_income: monthly_income_total.round(2),
        expense_count: expenses.count,
        income_count: income.count,
        currency: family.currency
      },
      upcoming_bills_30_days: upcoming_bills.first(10),
      note: "These are detected recurring patterns. Manual recurring transactions marked with is_manual: true."
    }
  end
end
