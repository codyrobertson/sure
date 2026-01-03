class Assistant::Function::GenerateSankeyChart < Assistant::Function
  class << self
    def name
      "generate_sankey_chart"
    end

    def description
      "Generate a sankey diagram showing cash flow from income sources to expense categories. " \
      "Use when the user wants to see where their money comes from and where it goes. " \
      "Can show top-level categories or detailed subcategories."
    end
  end

  # Disable strict mode since show_subcategories is optional
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
        period: {
          type: "string",
          enum: %w[current_month last_month last_90_days],
          description: "Time period for the cash flow"
        },
        show_subcategories: {
          type: "boolean",
          description: "If true, show all subcategories for more detail. Default: false (top-level only)"
        }
      },
      required: %w[title period]
    )
  end

  def call(params = {})
    report_progress("Generating cash flow chart...")

    period = parse_period(params["period"])
    show_subcategories = params["show_subcategories"] == true

    income_totals = family.income_statement.income_totals(period: period)
    expense_totals = family.income_statement.expense_totals(period: period)

    sankey_data = build_sankey_data(income_totals, expense_totals, show_subcategories)

    {
      chart_type: "sankey",
      title: params["title"],
      data: sankey_data
    }
  end

  private

    def parse_period(period_key)
      Period.from_key(period_key)
    rescue Period::InvalidKeyError
      Period.last_90_days
    end

    def build_sankey_data(income_totals, expense_totals, show_subcategories = false)
      nodes = []
      links = []
      node_indices = {}

      add_node = ->(unique_key, display_name, value, percentage, color) {
        node_indices[unique_key] ||= begin
          nodes << { name: display_name, value: value.to_f.round(2), percentage: percentage.to_f.round(1), color: color }
          nodes.size - 1
        end
      }

      total_income_val = income_totals.total.to_f.round(2)
      total_expense_val = expense_totals.total.to_f.round(2)

      # Central Cash Flow node
      cash_flow_idx = add_node.call("cash_flow_node", "Cash Flow", total_income_val, 100.0, "var(--color-success)")

      # Income categories
      income_totals.category_totals.each do |ct|
        # Skip subcategories unless show_subcategories is true
        next if ct.category.parent_id.present? && !show_subcategories
        # Skip parent categories if showing subcategories (to avoid double-counting)
        next if show_subcategories && ct.category.parent_id.nil? && has_subcategories?(ct.category)

        val = ct.total.to_f.round(2)
        next if val.zero?

        pct = total_income_val.zero? ? 0 : (val / total_income_val * 100).round(1)
        color = ct.category.color.presence || Category::COLORS.sample

        idx = add_node.call("income_#{ct.category.id}", ct.category.name, val, pct, color)
        links << { source: idx, target: cash_flow_idx, value: val, color: color, percentage: pct }
      end

      # Expense categories
      expense_totals.category_totals.each do |ct|
        # Skip subcategories unless show_subcategories is true
        next if ct.category.parent_id.present? && !show_subcategories
        # Skip parent categories if showing subcategories (to avoid double-counting)
        next if show_subcategories && ct.category.parent_id.nil? && has_subcategories?(ct.category)

        val = ct.total.to_f.round(2)
        next if val.zero?

        pct = total_expense_val.zero? ? 0 : (val / total_expense_val * 100).round(1)
        color = ct.category.color.presence || Category::UNCATEGORIZED_COLOR

        idx = add_node.call("expense_#{ct.category.id}", ct.category.name, val, pct, color)
        links << { source: cash_flow_idx, target: idx, value: val, color: color, percentage: pct }
      end

      # Surplus node
      leftover = (total_income_val - total_expense_val).round(2)
      if leftover.positive?
        pct = total_income_val.zero? ? 0 : (leftover / total_income_val * 100).round(1)
        surplus_idx = add_node.call("surplus_node", "Surplus", leftover, pct, "var(--color-success)")
        links << { source: cash_flow_idx, target: surplus_idx, value: leftover, color: "var(--color-success)", percentage: pct }
      end

      { nodes: nodes, links: links, currency_symbol: Money::Currency.new(family.currency).symbol }
    end

    def has_subcategories?(category)
      @subcategory_parents ||= family.categories.where.not(parent_id: nil).pluck(:parent_id).to_set
      @subcategory_parents.include?(category.id)
    end
end
