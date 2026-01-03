module Insights
  class BaseAnalyzer
    attr_reader :family, :period

    def initialize(family, period:)
      @family = family
      @period = period
    end

    def analyze
      Rails.cache.fetch(cache_key, expires_in: cache_duration) do
        perform_analysis
      end
    end

    private

    def perform_analysis
      raise NotImplementedError, "Subclasses must implement #perform_analysis"
    end

    def cache_key
      [
        "insights",
        self.class.name.demodulize.underscore,
        family.id,
        period.to_s,
        family.entries_cache_version
      ]
    end

    def cache_duration
      1.hour
    end

    # Common helpers for all analyzers

    def currency
      family.currency
    end

    def format_money(amount)
      {
        amount: amount.to_f.round(2),
        formatted: Money.new(amount, currency).format
      }
    end

    def entries
      @entries ||= family.entries
        .where(date: period.start_date..period.end_date)
        .includes(:account, entryable: [ :category, :merchant, :tags ])
    end

    # Returns entries that are transactions (with their entryable loaded)
    def transaction_entries
      @transaction_entries ||= entries
        .where(entryable_type: "Transaction")
    end

    # Returns Transaction objects (use entry association to get amount)
    def transactions
      @transactions ||= transaction_entries.map(&:entryable)
    end

    # Returns entries for expense transactions
    # Uses category classification (expense) or defaults to positive amounts
    def expense_entries
      @expense_entries ||= transaction_entries.select do |entry|
        next false if excluded_from_totals?(entry.entryable)

        transaction = entry.entryable
        category = transaction.category

        if category&.classification.present?
          category.classification == "expense"
        else
          # Fallback: positive amounts are expenses
          entry.amount.positive?
        end
      end
    end

    # Returns entries for income transactions
    # Uses category classification (income) - this is the authoritative source
    def income_entries
      @income_entries ||= transaction_entries.select do |entry|
        next false if excluded_from_totals?(entry.entryable)

        transaction = entry.entryable
        category = transaction.category

        if category&.classification.present?
          category.classification == "income"
        else
          # Fallback: negative amounts are income (but prefer category)
          entry.amount.negative?
        end
      end
    end

    # Legacy helpers for backward compatibility
    def expense_transactions
      expense_entries.map(&:entryable)
    end

    def income_transactions
      income_entries.map(&:entryable)
    end

    def excluded_from_totals?(transaction)
      %w[funds_movement one_time cc_payment loan_payment].include?(transaction.kind)
    end

    # Helper to get amount from entry (positive = expense, negative = income)
    def transaction_amount(entry_or_transaction)
      if entry_or_transaction.is_a?(Entry)
        entry_or_transaction.amount
      else
        entry_or_transaction.entry.amount
      end
    end

    def accounts
      @accounts ||= family.accounts.active
    end

    def categories
      @categories ||= family.categories
    end

    def merchants
      @merchants ||= family.merchants
    end

    # Period helpers for comparisons

    def previous_period
      @previous_period ||= begin
        duration = period.end_date - period.start_date
        Period.custom(
          start_date: period.start_date - duration - 1.day,
          end_date: period.start_date - 1.day
        )
      end
    end

    def entries_for_period(p)
      family.entries
        .where(date: p.start_date..p.end_date)
        .includes(:account, entryable: [ :category, :merchant, :tags ])
    end

    def transactions_for_period(p)
      entries_for_period(p)
        .where(entryable_type: "Transaction")
        .map(&:entryable)
    end

    # Historical data helpers

    def monthly_periods(months_back: 3)
      (0...months_back).map do |i|
        month_start = (Date.current - i.months).beginning_of_month
        month_end = (Date.current - i.months).end_of_month
        month_end = Date.current if month_end > Date.current
        Period.custom(start_date: month_start, end_date: month_end)
      end.reverse
    end

    def calculate_trend(current_value, previous_value)
      return { direction: :stable, percent: 0 } if previous_value.zero?

      change = ((current_value - previous_value) / previous_value.abs * 100).round(1)

      direction = if change > 5
        :up
      elsif change < -5
        :down
      else
        :stable
      end

      { direction: direction, percent: change.abs }
    end

    # Insight generation helpers

    def build_insight(type:, message:, severity: :info, data: {})
      {
        type: type,
        message: message,
        severity: severity,
        data: data
      }
    end

    def severity_for_deviation(deviation_percent)
      if deviation_percent >= 200
        :critical
      elsif deviation_percent >= 150
        :warning
      else
        :info
      end
    end
  end
end
