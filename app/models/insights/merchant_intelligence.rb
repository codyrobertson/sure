module Insights
  class MerchantIntelligence < BaseAnalyzer
    TOP_MERCHANTS_COUNT = 10

    private

    def perform_analysis
      {
        top_merchants: analyze_top_merchants,
        new_merchants: find_new_merchants,
        frequency_leaders: find_frequency_leaders,
        category_breakdown: analyze_by_category,
        insights: generate_insights
      }
    end

    def analyze_top_merchants
      current_spending = spending_by_merchant(period)
      previous_spending = spending_by_merchant(previous_period)

      current_spending
        .sort_by { |_, data| -data[:total] }
        .first(TOP_MERCHANTS_COUNT)
        .map do |merchant_id, data|
          merchant = merchants.find { |m| m.id == merchant_id }
          next unless merchant

          prev = previous_spending[merchant_id] || { total: 0, count: 0 }
          trend = calculate_trend(data[:total], prev[:total])

          {
            merchant: {
              id: merchant.id,
              name: merchant.name
            },
            total_spent: format_money(data[:total]),
            transaction_count: data[:count],
            avg_transaction: format_money(data[:count].positive? ? data[:total] / data[:count] : 0),
            trend: trend[:direction],
            trend_percent: trend[:percent],
            categories: data[:categories].uniq.first(3)
          }
        end.compact
    end

    def find_new_merchants
      current_merchant_ids = merchant_ids_in_period(period)
      historical_merchant_ids = merchant_ids_before_period

      new_ids = current_merchant_ids - historical_merchant_ids
      return [] if new_ids.empty?

      spending = spending_by_merchant(period)

      new_ids.map do |merchant_id|
        merchant = merchants.find { |m| m.id == merchant_id }
        next unless merchant

        data = spending[merchant_id] || { total: 0, count: 0 }

        # Find first transaction date
        first_tx = expense_transactions
          .select { |t| t.merchant_id == merchant_id }
          .min_by { |t| t.entry.date }

        {
          merchant: {
            id: merchant.id,
            name: merchant.name
          },
          first_date: first_tx&.entry&.date&.to_s,
          total_spent: format_money(data[:total]),
          transaction_count: data[:count]
        }
      end.compact.sort_by { |m| -m[:total_spent][:amount] }.first(10)
    end

    def find_frequency_leaders
      spending = spending_by_merchant(period)

      spending
        .select { |_, data| data[:count] >= 3 } # At least 3 visits
        .sort_by { |_, data| -data[:count] }
        .first(5)
        .map do |merchant_id, data|
          merchant = merchants.find { |m| m.id == merchant_id }
          next unless merchant

          days_in_period = (period.end_date - period.start_date).to_i + 1
          visits_per_month = (data[:count] / (days_in_period / 30.0)).round(1)

          {
            merchant: {
              id: merchant.id,
              name: merchant.name
            },
            visits_this_period: data[:count],
            avg_per_month: visits_per_month,
            total_spent: format_money(data[:total]),
            avg_per_visit: format_money(data[:total] / data[:count])
          }
        end.compact
    end

    def analyze_by_category
      result = {}

      expense_transactions.each do |transaction|
        next unless transaction.merchant_id

        category_name = transaction.category&.name || "Uncategorized"
        merchant = transaction.merchant
        next unless merchant

        result[category_name] ||= { total: 0, merchants: {} }
        result[category_name][:total] += transaction.entry.amount.abs
        result[category_name][:merchants][merchant.id] ||= {
          name: merchant.name,
          total: 0,
          count: 0
        }
        result[category_name][:merchants][merchant.id][:total] += transaction.entry.amount.abs
        result[category_name][:merchants][merchant.id][:count] += 1
      end

      result.map do |category, data|
        top_merchants = data[:merchants]
          .values
          .sort_by { |m| -m[:total] }
          .first(3)
          .map do |m|
            {
              name: m[:name],
              total: format_money(m[:total]),
              count: m[:count]
            }
          end

        {
          category: category,
          total: format_money(data[:total]),
          top_merchants: top_merchants
        }
      end.sort_by { |c| -c[:total][:amount] }.first(5)
    end

    def generate_insights
      insights = []
      top = analyze_top_merchants

      # Top merchant concentration
      if top.any?
        top_merchant = top.first
        total_spending = expense_transactions.sum { |t| t.entry.amount.abs }
        concentration = (top_merchant[:total_spent][:amount] / total_spending * 100).round(1) if total_spending.positive?

        if concentration && concentration > 20
          insights << build_insight(
            type: :high_concentration,
            message: "#{concentration}% of your spending goes to #{top_merchant[:merchant][:name]}.",
            severity: :info
          )
        end
      end

      # Trending up merchants
      trending_up = top.select { |m| m[:trend] == :up && m[:trend_percent] > 25 }
      if trending_up.any?
        names = trending_up.first(2).map { |m| m[:merchant][:name] }.join(" and ")
        insights << build_insight(
          type: :spending_increase,
          message: "Spending at #{names} is up significantly from last period.",
          severity: :warning
        )
      end

      # New merchants discovery
      new_merchants = find_new_merchants
      if new_merchants.length >= 5
        insights << build_insight(
          type: :many_new_merchants,
          message: "You shopped at #{new_merchants.length} new merchants this period.",
          severity: :info
        )
      end

      # Frequent visitor
      freq = find_frequency_leaders.first
      if freq && freq[:visits_this_period] >= 10
        insights << build_insight(
          type: :frequent_visitor,
          message: "You visited #{freq[:merchant][:name]} #{freq[:visits_this_period]} times, averaging #{freq[:avg_per_visit][:formatted]} per visit.",
          severity: :info
        )
      end

      insights
    end

    # Helpers

    def spending_by_merchant(p)
      result = {}

      entries_for_period(p).where(entryable_type: "Transaction").each do |entry|
        transaction = entry.entryable
        next unless entry.amount.positive? # Expenses only
        next if excluded_from_totals?(transaction)
        next unless transaction.merchant_id

        result[transaction.merchant_id] ||= { total: 0, count: 0, categories: [] }
        result[transaction.merchant_id][:total] += entry.amount.abs
        result[transaction.merchant_id][:count] += 1
        result[transaction.merchant_id][:categories] << transaction.category&.name if transaction.category
      end

      result
    end

    def merchant_ids_in_period(p)
      entries_for_period(p)
        .where(entryable_type: "Transaction")
        .select { |e| e.amount.positive? && e.entryable.merchant_id.present? }
        .map { |e| e.entryable.merchant_id }
        .uniq
    end

    def merchant_ids_before_period
      family.entries
        .where("date < ?", period.start_date)
        .where(entryable_type: "Transaction")
        .includes(entryable: :merchant)
        .map { |e| e.entryable.merchant_id }
        .compact
        .uniq
    end
  end
end
