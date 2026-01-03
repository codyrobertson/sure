class Assistant::Function::GenerateAccountBalanceChart < Assistant::Function
  class << self
    def name
      "generate_account_balance_chart"
    end

    def description
      "Generate a time series chart showing a specific account's balance over time. " \
      "Use when the user asks about a particular account's balance history."
    end
  end

  def params_schema
    build_schema(
      properties: {
        title: {
          type: "string",
          description: "Chart title displayed above the visualization"
        },
        account_id: {
          type: "string",
          description: "The account UUID to chart"
        },
        period: {
          type: "string",
          enum: %w[last_30_days last_90_days last_365_days all_time],
          description: "Time period for the chart"
        }
      },
      required: %w[title account_id period]
    )
  end

  def call(params = {})
    report_progress("Generating account balance chart...")

    account = family.accounts.find_by(id: params["account_id"])
    return { error: "Account not found" } unless account

    period = parse_period(params["period"])
    series_data = account.balance_series(period: period)

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
end
