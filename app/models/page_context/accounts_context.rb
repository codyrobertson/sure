class PageContext::AccountsContext < PageContext::Base
  def page_name
    :accounts
  end

  def page_icon
    "landmark"
  end

  def available?
    family.accounts.visible.exists?
  end

  private

    def generate_prompts
      prompts = []

      # Account-specific prompts if viewing a specific account
      if current_account.present?
        prompts << build_prompt(
          icon: "chart-line",
          text: t("analyze_account", account_name: current_account.name),
          category: :analysis
        )

        prompts << build_prompt(
          icon: "trending-up",
          text: t("account_balance_trend", account_name: current_account.name),
          category: :analysis
        )
      else
        # General account prompts
        prompts << build_prompt(
          icon: "scale",
          text: t("compare_accounts"),
          category: :analysis
        )

        prompts << build_prompt(
          icon: "pie-chart",
          text: t("net_worth_breakdown"),
          category: :analysis
        )
      end

      # Account balance trends
      prompts << build_prompt(
        icon: "trending-up",
        text: t("account_trends"),
        category: :analysis
      )

      # Sync status (if accounts have sync issues)
      if accounts_with_sync_issues?
        prompts << build_prompt(
          icon: "alert-circle",
          text: t("sync_status"),
          category: :discovery
        )
      end

      prompts.first(MAX_PROMPTS)
    end

    def current_account
      return nil unless metadata[:account_id].present?

      @current_account ||= family.accounts.find_by(id: metadata[:account_id])
    end

    def accounts_with_sync_issues?
      family.accounts.visible.joins(:syncs)
        .where(syncs: { status: "error" })
        .exists?
    end

    def cache_version
      account_id = metadata[:account_id] || "all"
      account_count = family.accounts.visible.count
      "v1:#{account_id}:ac#{account_count}"
    end
end
