class PageContext::TransactionsContext < PageContext::Base
  def page_name
    :transactions
  end

  def page_icon
    "credit-card"
  end

  def available?
    family.transactions.exists?
  end

  private

    def generate_prompts
      prompts = []

      # Uncategorized transactions prompt
      if uncategorized_count > 0
        prompts << build_prompt(
          icon: "tag",
          text: t("categorize_uncategorized", count: uncategorized_count),
          category: :action
        )
      end

      # Search context prompt (if user has active filters)
      if metadata[:has_filters]
        prompts << build_prompt(
          icon: "search",
          text: t("analyze_filtered_results"),
          category: :analysis
        )
      end

      # Recent spending analysis
      prompts << build_prompt(
        icon: "trending-down",
        text: t("analyze_recent_spending"),
        category: :analysis
      )

      # Recurring transactions
      prompts << build_prompt(
        icon: "repeat",
        text: t("find_recurring"),
        category: :discovery
      )

      # Automation rules suggestion
      prompts << build_prompt(
        icon: "zap",
        text: t("setup_automation"),
        category: :action
      )

      prompts.first(MAX_PROMPTS)
    end

    def uncategorized_count
      @uncategorized_count ||= family.transactions
        .joins(:entry)
        .where(category_id: nil)
        .where(entries: { date: current_period.date_range })
        .count
    end

    def cache_version
      # Invalidate when uncategorized count changes significantly (every 10)
      uncategorized_bucket = (uncategorized_count / 10) * 10
      "v1:uc#{uncategorized_bucket}"
    end
end
