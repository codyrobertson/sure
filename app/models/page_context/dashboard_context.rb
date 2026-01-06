class PageContext::DashboardContext < PageContext::Base
  def page_name
    :dashboard
  end

  def page_icon
    "pie-chart"
  end

  def available?
    family.accounts.visible.exists?
  end

  private

    def generate_prompts
      prompts = []

      # Net worth analysis
      prompts << build_prompt(
        icon: "trending-up",
        text: t("analyze_net_worth"),
        category: :analysis
      )

      # Spending breakdown
      prompts << build_prompt(
        icon: "pie-chart",
        text: t("spending_breakdown"),
        category: :analysis
      )

      # Cash flow / sustainability
      prompts << build_prompt(
        icon: "scale",
        text: t("cash_flow_analysis"),
        category: :analysis
      )

      # Investment performance (if user has investments)
      if has_investments?
        prompts << build_prompt(
          icon: "chart-candlestick",
          text: t("investment_performance"),
          category: :analysis
        )
      end

      # Savings opportunities
      prompts << build_prompt(
        icon: "lightbulb",
        text: t("savings_opportunities"),
        category: :discovery
      )

      prompts.first(MAX_PROMPTS)
    end

    def has_investments?
      family.accounts.where(accountable_type: "Investment").exists?
    end

    def cache_version
      # Invalidate based on account count changes
      account_count = family.accounts.visible.count
      "v1:ac#{account_count}"
    end
end
