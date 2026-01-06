class PageContext::InvestmentsContext < PageContext::Base
  def page_name
    :investments
  end

  def page_icon
    "chart-candlestick"
  end

  def available?
    family.accounts.where(accountable_type: "Investment").exists?
  end

  private

    def generate_prompts
      prompts = []

      # Portfolio performance
      prompts << build_prompt(
        icon: "trending-up",
        text: t("portfolio_performance"),
        category: :analysis
      )

      # Asset allocation
      prompts << build_prompt(
        icon: "pie-chart",
        text: t("asset_allocation"),
        category: :analysis
      )

      # Top holdings analysis
      if has_holdings?
        prompts << build_prompt(
          icon: "search",
          text: t("holdings_analysis"),
          category: :analysis
        )
      end

      # Dividend income (if applicable)
      if has_dividend_income?
        prompts << build_prompt(
          icon: "coins",
          text: t("dividends_income"),
          category: :analysis
        )
      end

      # Investment comparison
      prompts << build_prompt(
        icon: "scale",
        text: t("investment_comparison"),
        category: :analysis
      )

      prompts.first(MAX_PROMPTS)
    end

    def has_holdings?
      family.holdings.exists?
    end

    def has_dividend_income?
      # Check if there are any dividend transactions
      family.transactions
        .joins(:category)
        .where(categories: { name: [ "Dividends", "Dividend Income" ] })
        .exists?
    end

    def cache_version
      holdings_count = family.holdings.count
      "v1:hc#{holdings_count}"
    end
end
