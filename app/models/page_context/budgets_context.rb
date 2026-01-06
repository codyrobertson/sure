class PageContext::BudgetsContext < PageContext::Base
  def page_name
    :budgets
  end

  def page_icon
    "map"
  end

  def available?
    true # Always available - can suggest creating budgets
  end

  private

    def generate_prompts
      prompts = []

      if has_budgets?
        # Budget vs actual analysis
        prompts << build_prompt(
          icon: "target",
          text: t("budget_vs_actual"),
          category: :analysis
        )

        # Overspending categories
        if overspent_categories_count > 0
          prompts << build_prompt(
            icon: "alert-triangle",
            text: t("overspending_categories", count: overspent_categories_count),
            category: :analysis
          )
        end

        # Budget optimization
        prompts << build_prompt(
          icon: "lightbulb",
          text: t("budget_optimization"),
          category: :discovery
        )

        # Remaining budget
        prompts << build_prompt(
          icon: "wallet",
          text: t("remaining_budget"),
          category: :analysis
        )
      else
        # No budgets - suggest creation
        prompts << build_prompt(
          icon: "sparkles",
          text: t("create_budget"),
          category: :action
        )

        prompts << build_prompt(
          icon: "calculator",
          text: t("analyze_for_budget"),
          category: :discovery
        )
      end

      prompts.first(MAX_PROMPTS)
    end

    def has_budgets?
      family.budgets.exists?
    end

    def overspent_categories_count
      @overspent_count ||= begin
        return 0 unless has_budgets?

        current_budget = family.budgets.find_by(start_date: Date.current.beginning_of_month)
        return 0 unless current_budget

        current_budget.budget_categories.select(&:over_budget?).count
      end
    end

    def cache_version
      budget_count = family.budgets.count
      overspent = overspent_categories_count
      "v1:bc#{budget_count}:os#{overspent}"
    end
end
