class PageContext::ReportsContext < PageContext::Base
  def page_name
    :reports
  end

  def page_icon
    "chart-bar"
  end

  def available?
    family.transactions.exists?
  end

  private

    def generate_prompts
      prompts = []

      # Income vs expenses
      prompts << build_prompt(
        icon: "scale",
        text: t("income_vs_expenses"),
        category: :analysis
      )

      # Spending trends
      prompts << build_prompt(
        icon: "trending-up",
        text: t("spending_trends"),
        category: :analysis
      )

      # Top spending category deep dive
      if top_spending_category.present?
        prompts << build_prompt(
          icon: "search",
          text: t("category_deep_dive", category: top_spending_category),
          category: :analysis
        )
      end

      # Savings rate
      prompts << build_prompt(
        icon: "piggy-bank",
        text: t("savings_rate"),
        category: :analysis
      )

      # Cash flow timing
      prompts << build_prompt(
        icon: "calendar",
        text: t("cash_flow_timing"),
        category: :discovery
      )

      prompts.first(MAX_PROMPTS)
    end

    def top_spending_category
      @top_spending_category ||= begin
        income_statement = family.income_statement
        expense_totals = income_statement.expense_totals(period: current_period)

        top = expense_totals.category_totals
          .reject { |ct| ct.total.zero? }
          .max_by { |ct| ct.total }

        top&.category&.name
      end
    end

    def cache_version
      # Invalidate monthly
      "v1:#{Date.current.beginning_of_month}"
    end
end
