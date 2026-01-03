module Insights
  class AnomalyDetector < BaseAnalyzer
    DEVIATION_WARNING_THRESHOLD = 150  # 150% of average
    DEVIATION_ALERT_THRESHOLD = 200    # 200% of average
    MIN_TRANSACTIONS_FOR_AVERAGE = 3   # Need at least 3 transactions to establish baseline
    TOP_TRANSACTIONS_COUNT = 3

    private

    def perform_analysis
      {
        anomalies: detect_category_anomalies,
        new_merchants: detect_new_merchants,
        summary: build_summary
      }
    end

    def detect_category_anomalies
      current_by_category = spending_by_category(period)
      historical_average = calculate_historical_average

      anomalies = []

      current_by_category.each do |category_id, current_data|
        category = categories.find { |c| c.id == category_id }
        next unless category

        average_amount = historical_average[category_id] || 0

        # Skip if no historical baseline
        next if average_amount.zero?

        current_amount = current_data[:amount]
        deviation_percent = (current_amount / average_amount * 100).round(1)

        # Only flag if above warning threshold
        next if deviation_percent < DEVIATION_WARNING_THRESHOLD

        severity = deviation_percent >= DEVIATION_ALERT_THRESHOLD ? :alert : :warning

        anomalies << {
          category: {
            id: category.id,
            name: category.name,
            color: category.color
          },
          current: format_money(current_amount),
          average: format_money(average_amount),
          deviation_percent: deviation_percent,
          severity: severity,
          top_transactions: top_transactions_for_category(category_id)
        }
      end

      # Sort by deviation (highest first)
      anomalies.sort_by { |a| -a[:deviation_percent] }
    end

    def detect_new_merchants
      current_merchant_ids = merchant_ids_for_period(period)
      historical_merchant_ids = merchant_ids_for_historical_periods

      new_merchant_ids = current_merchant_ids - historical_merchant_ids
      return [] if new_merchant_ids.empty?

      # Get spending data for new merchants
      new_merchants_data = []

      expense_transactions.each do |transaction|
        next unless transaction.merchant_id.in?(new_merchant_ids)

        merchant = transaction.merchant
        next unless merchant

        existing = new_merchants_data.find { |m| m[:merchant][:id] == merchant.id }

        if existing
          existing[:total_spent][:amount] += transaction.entry.amount.abs
          existing[:transaction_count] += 1
        else
          new_merchants_data << {
            merchant: {
              id: merchant.id,
              name: merchant.name
            },
            total_spent: { amount: transaction.entry.amount.abs, formatted: nil },
            transaction_count: 1,
            first_transaction_date: transaction.entry.date
          }
        end
      end

      # Format money values
      new_merchants_data.each do |data|
        data[:total_spent] = format_money(data[:total_spent][:amount])
      end

      # Sort by total spent (highest first)
      new_merchants_data.sort_by { |m| -m[:total_spent][:amount] }.first(10)
    end

    def build_summary
      anomalies = detect_category_anomalies

      total_current = anomalies.sum { |a| a[:current][:amount] }
      total_average = anomalies.sum { |a| a[:average][:amount] }
      total_deviation = total_current - total_average

      {
        anomaly_count: anomalies.count,
        alert_count: anomalies.count { |a| a[:severity] == :alert },
        warning_count: anomalies.count { |a| a[:severity] == :warning },
        total_deviation: format_money(total_deviation),
        new_merchant_count: detect_new_merchants.count
      }
    end

    # Helpers

    def spending_by_category(p)
      result = {}

      entries_for_period(p).where(entryable_type: "Transaction").each do |entry|
        transaction = entry.entryable
        next unless entry.amount.positive? # Expenses only
        next if excluded_from_totals?(transaction)
        next unless transaction.category_id

        result[transaction.category_id] ||= { amount: 0, count: 0 }
        result[transaction.category_id][:amount] += entry.amount.abs
        result[transaction.category_id][:count] += 1
      end

      result
    end

    def calculate_historical_average
      # Get 3 months of historical data (excluding current period)
      periods = historical_periods(months: 3)
      return {} if periods.empty?

      # Sum spending across all periods
      totals = {}
      counts = {}

      periods.each do |p|
        spending = spending_by_category(p)
        spending.each do |category_id, data|
          totals[category_id] ||= 0
          counts[category_id] ||= 0
          totals[category_id] += data[:amount]
          counts[category_id] += 1
        end
      end

      # Calculate averages
      averages = {}
      totals.each do |category_id, total|
        # Only include categories with sufficient history
        next if counts[category_id] < MIN_TRANSACTIONS_FOR_AVERAGE
        averages[category_id] = total / counts[category_id]
      end

      averages
    end

    def historical_periods(months: 3)
      # Get previous months, not overlapping with current period
      result = []
      current_end = period.start_date - 1.day

      months.times do |i|
        month_end = (current_end - i.months).end_of_month
        month_start = month_end.beginning_of_month

        # Don't go beyond current_end for the first month
        month_end = current_end if i == 0 && month_end > current_end

        result << Period.custom(start_date: month_start, end_date: month_end)
      end

      result
    end

    def top_transactions_for_category(category_id)
      matching = expense_transactions
        .select { |t| t.category_id == category_id }
        .sort_by { |t| -t.entry.amount.abs }
        .first(TOP_TRANSACTIONS_COUNT)

      matching.map do |transaction|
        entry = transaction.entry
        {
          id: transaction.id,
          name: transaction.name,
          amount: format_money(entry.amount.abs),
          date: entry.date.to_s,
          merchant: transaction.merchant&.name
        }
      end
    end

    def merchant_ids_for_period(p)
      entries_for_period(p)
        .where(entryable_type: "Transaction")
        .select { |e| e.amount.positive? && e.entryable.merchant_id.present? }
        .map { |e| e.entryable.merchant_id }
        .uniq
    end

    def merchant_ids_for_historical_periods
      historical_periods(months: 3).flat_map do |p|
        merchant_ids_for_period(p)
      end.uniq
    end
  end
end
