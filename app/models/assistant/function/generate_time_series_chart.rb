class Assistant::Function::GenerateTimeSeriesChart < Assistant::Function
  class << self
    def name
      "generate_time_series_chart"
    end

    def description
      "Generate a time series line chart showing trends over time. " \
      "Use for: net worth history, spending trends, or income trends. " \
      "Can filter spending/income to a specific category. " \
      "For individual account balances, use generate_account_balance_chart instead."
    end
  end

  # Disable strict mode since category is optional
  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      properties: {
        title: {
          type: "string",
          description: "Chart title displayed above the visualization"
        },
        metric: {
          type: "string",
          enum: %w[net_worth spending income],
          description: "Which metric to chart"
        },
        period: {
          type: "string",
          enum: %w[last_30_days last_90_days last_365_days all_time],
          description: "Time period for the chart"
        },
        category: {
          type: "string",
          description: "Optional: filter spending/income to a specific category (e.g., 'Dining', 'Groceries')"
        }
      },
      required: %w[title metric period]
    )
  end

  def call(params = {})
    report_progress("Generating time series chart...")

    period = parse_period(params["period"])
    metric = params["metric"]
    category_name = params["category"]

    series_data = case metric
    when "net_worth"
      family.balance_sheet.net_worth_series(period: period)
    when "spending"
      build_spending_series(period, category_name)
    when "income"
      build_income_series(period, category_name)
    else
      return { error: "Unknown metric: #{metric}" }
    end

    {
      chart_type: "time_series",
      title: params["title"],
      data: series_data.as_json
    }
  end

  private

    def parse_period(period_key)
      Period.from_key(period_key)
    rescue Period::InvalidKeyError
      Period.last_90_days
    end

    def find_category_ids(category_name)
      return nil unless category_name.present?

      category = family.categories.find_by("LOWER(name) = ?", category_name.downcase)
      return nil unless category

      # Include the category and all its subcategories
      [category.id] + family.categories.where(parent_id: category.id).pluck(:id)
    end

    def build_spending_series(period, category_name = nil)
      # Filter to expense transactions by category classification
      # Use left_outer_joins to include uncategorized transactions when not filtering by category
      scope = family.transactions
        .joins(:entry)
        .left_outer_joins(:category)
        .where(entries: { date: period.date_range })
        .where("entries.amount > 0") # Expenses have positive amounts

      if category_name.present?
        category_ids = find_category_ids(category_name)
        return empty_series(period) unless category_ids
        scope = scope.where(category_id: category_ids)
      else
        # When not filtering, include expenses (positive amounts) or uncategorized
        scope = scope.where("categories.classification = ? OR transactions.category_id IS NULL", "expense")
      end

      transactions = scope.group("entries.date").sum("entries.amount")

      # Build raw values first
      raw_values = period.date_range.map do |date|
        amount = transactions[date] || 0
        { date: date, value: Money.new((amount * 100).to_i, family.currency) }
      end

      # Create Series::Value objects with trend (comparing to previous value)
      values = [nil, *raw_values].each_cons(2).map do |prev, curr|
        Series::Value.new(
          date: curr[:date],
          date_formatted: I18n.l(curr[:date], format: :long),
          value: curr[:value],
          trend: Trend.new(
            current: curr[:value],
            previous: prev&.[](:value),
            favorable_direction: "down" # Lower spending is good
          )
        )
      end

      Series.new(
        start_date: period.start_date,
        end_date: period.end_date,
        interval: period.interval,
        values: values,
        favorable_direction: "down"
      )
    end

    def build_income_series(period, category_name = nil)
      # Filter to income transactions by category classification
      # Use left_outer_joins to include uncategorized transactions when not filtering by category
      scope = family.transactions
        .joins(:entry)
        .left_outer_joins(:category)
        .where(entries: { date: period.date_range })
        .where("entries.amount < 0") # Income has negative amounts

      if category_name.present?
        category_ids = find_category_ids(category_name)
        return empty_series(period) unless category_ids
        scope = scope.where(category_id: category_ids)
      else
        # When not filtering, include income (negative amounts) or uncategorized
        scope = scope.where("categories.classification = ? OR transactions.category_id IS NULL", "income")
      end

      transactions = scope.group("entries.date").sum("entries.amount")

      # Build raw values first
      raw_values = period.date_range.map do |date|
        amount = (transactions[date] || 0).abs
        { date: date, value: Money.new((amount * 100).to_i, family.currency) }
      end

      # Create Series::Value objects with trend (comparing to previous value)
      values = [nil, *raw_values].each_cons(2).map do |prev, curr|
        Series::Value.new(
          date: curr[:date],
          date_formatted: I18n.l(curr[:date], format: :long),
          value: curr[:value],
          trend: Trend.new(
            current: curr[:value],
            previous: prev&.[](:value),
            favorable_direction: "up" # Higher income is good
          )
        )
      end

      Series.new(
        start_date: period.start_date,
        end_date: period.end_date,
        interval: period.interval,
        values: values,
        favorable_direction: "up"
      )
    end

    def empty_series(period)
      zero_money = Money.new(0, family.currency)

      # Build raw values
      raw_values = period.date_range.map do |date|
        { date: date, value: zero_money }
      end

      # Create Series::Value objects with trend
      values = [nil, *raw_values].each_cons(2).map do |prev, curr|
        Series::Value.new(
          date: curr[:date],
          date_formatted: I18n.l(curr[:date], format: :long),
          value: curr[:value],
          trend: Trend.new(
            current: curr[:value],
            previous: prev&.[](:value)
          )
        )
      end

      Series.new(
        start_date: period.start_date,
        end_date: period.end_date,
        interval: period.interval,
        values: values
      )
    end
end
