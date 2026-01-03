class Assistant::Function::GetCashFlow < Assistant::Function
  class << self
    def name
      "get_cash_flow"
    end

    def description
      "Get cash flow analysis with sustainability metrics. Shows income vs total outflow (lifestyle + debt payments), " \
      "funding gaps, and where extra money is coming from (savings drawdown, investment liquidation). " \
      "Use this when users ask about: sustainability, living within means, whether they can afford their lifestyle, " \
      "debt payment coverage, or funding sources."
    end
  end

  def params_schema
    {
      type: "object",
      properties: {
        period: {
          type: "string",
          enum: [
            "current_month",
            "last_month",
            "last_30_days",
            "last_90_days",
            "last_365_days",
            "year_to_date"
          ],
          description: "Time period for the analysis (default: last_30_days)"
        }
      },
      required: []
    }
  end

  def call(params = {})
    period = build_period(params["period"] || "last_30_days")
    analyzer = CashFlowAnalyzer.new(family, period: period)
    result = analyzer.analyze

    format_result(result, period)
  rescue => e
    { error: e.message }
  end

  private

  def build_period(period_name)
    case period_name
    when "current_month"
      Period.current_month
    when "last_month"
      Period.last_month
    when "last_30_days"
      Period.last_30_days
    when "last_90_days"
      Period.custom(start_date: 90.days.ago.to_date, end_date: Date.current)
    when "last_365_days"
      Period.last_365_days
    when "year_to_date"
      Period.custom(start_date: Date.current.beginning_of_year, end_date: Date.current)
    else
      Period.last_30_days
    end
  end

  def format_result(result, period)
    currency = family.currency

    {
      period: {
        start_date: period.start_date.to_s,
        end_date: period.end_date.to_s
      },
      summary: {
        income: format_money(result[:income], currency),
        lifestyle_expenses: format_money(result[:lifestyle_expenses], currency),
        debt_payments_total: format_money(result[:debt_payments][:total], currency),
        total_outflow: format_money(result[:sustainability][:total_outflow], currency),
        funding_gap: format_money(result[:sustainability][:funding_gap], currency),
        coverage_percent: result[:sustainability][:coverage_percent],
        sustainable: result[:sustainability][:sustainable]
      },
      debt_payments: {
        credit_cards: format_money(result[:debt_payments][:credit_cards], currency),
        loans: format_money(result[:debt_payments][:loans], currency),
        total: format_money(result[:debt_payments][:total], currency)
      },
      funding_sources: format_funding_sources(result[:sustainability][:funding_sources], currency),
      insights: result[:sustainability][:insights].map { |i| { type: i[:type].to_s, message: i[:message] } }
    }
  end

  def format_money(amount, currency)
    {
      amount: amount.to_f.round(2),
      formatted: Money.new(amount, currency).format
    }
  end

  def format_funding_sources(sources, currency)
    sources.transform_values do |amount|
      {
        amount: amount.to_f.round(2),
        formatted: Money.new(amount, currency).format
      }
    end
  end
end
