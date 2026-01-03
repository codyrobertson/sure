class Assistant::Function::GenerateDonutChart < Assistant::Function
  class << self
    def name
      "generate_donut_chart"
    end

    def description
      "Generate a donut chart showing category breakdown. " \
      "Use for: spending by category or income by category visualizations. " \
      "Can show all top-level categories OR subcategories of a specific parent category."
    end
  end

  # Disable strict mode since parent_category is optional
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
        breakdown_type: {
          type: "string",
          enum: %w[spending_by_category income_by_category],
          description: "What to break down by category"
        },
        period: {
          type: "string",
          enum: %w[current_month last_month last_30_days last_90_days last_365_days],
          description: "Time period for the breakdown"
        },
        parent_category: {
          type: "string",
          description: "Optional: show only subcategories of this parent category (e.g., 'Dining' to see Restaurant, Fast Food, etc.)"
        }
      },
      required: %w[title breakdown_type period]
    )
  end

  def call(params = {})
    report_progress("Generating donut chart...")

    period = parse_period(params["period"])
    breakdown_type = params["breakdown_type"]
    parent_category_name = params["parent_category"]

    segments = case breakdown_type
    when "spending_by_category"
      expense_totals = family.income_statement.expense_totals(period: period)
      build_segments(expense_totals, parent_category_name)
    when "income_by_category"
      income_totals = family.income_statement.income_totals(period: period)
      build_segments(income_totals, parent_category_name)
    else
      return { error: "Unknown breakdown type: #{breakdown_type}" }
    end

    if segments.empty?
      return { error: "No data found for the specified category and period" }
    end

    {
      chart_type: "donut",
      title: params["title"],
      data: {
        segments: segments,
        currency_symbol: Money::Currency.new(family.currency).symbol
      }
    }
  end

  private

    def parse_period(period_key)
      Period.from_key(period_key)
    rescue Period::InvalidKeyError
      Period.last_90_days
    end

    def build_segments(totals, parent_category_name = nil)
      category_totals = totals.category_totals.reject { |ct| ct.total.zero? }

      if parent_category_name.present?
        # Find the parent category
        parent = family.categories.find_by("LOWER(name) = ?", parent_category_name.downcase)
        return [] unless parent

        # Filter to only subcategories of this parent
        category_totals = category_totals.select { |ct| ct.category.parent_id == parent.id }

        # Recalculate percentages based on parent total
        parent_total = category_totals.sum(&:total)
        category_totals
          .sort_by { |ct| -ct.total }
          .map do |ct|
            pct = parent_total.zero? ? 0 : (ct.total / parent_total * 100).round(1)
            {
              id: ct.category.id,
              name: ct.category.name,
              amount: ct.total.to_f.round(2),
              currency: ct.currency,
              percentage: pct,
              color: ct.category.color.presence || Category::UNCATEGORIZED_COLOR
            }
          end
      else
        # Show only top-level categories (no parent)
        category_totals
          .reject { |ct| ct.category.parent_id.present? }
          .sort_by { |ct| -ct.total }
          .map do |ct|
            {
              id: ct.category.id,
              name: ct.category.name,
              amount: ct.total.to_f.round(2),
              currency: ct.currency,
              percentage: ct.weight.round(1),
              color: ct.category.color.presence || Category::UNCATEGORIZED_COLOR
            }
          end
      end
    end
end
