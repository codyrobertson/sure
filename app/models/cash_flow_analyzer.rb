class CashFlowAnalyzer
  attr_reader :family, :period

  def initialize(family, period:)
    @family = family
    @period = period
  end

  def analyze
    {
      income: income_total,
      lifestyle_expenses: lifestyle_expenses_total,
      debt_payments: debt_payments_breakdown,
      savings_contributions: savings_contributions_total,
      investment_contributions: investment_contributions_total,
      sustainability: sustainability_metrics
    }
  end

  # True income (paychecks, interest, etc.) - excludes transfers
  def income_total
    family.income_statement.income_totals(period: period).total
  end

  # Lifestyle expenses (groceries, dining, etc.) - excludes debt payments
  def lifestyle_expenses_total
    family.income_statement.expense_totals(period: period).total
  end

  # Debt payments broken down by type
  def debt_payments_breakdown
    payments = debt_payment_transactions

    cc_payments = payments.select { |t| t.kind == "cc_payment" }
    loan_payments = payments.select { |t| t.kind == "loan_payment" }

    {
      credit_cards: sum_amounts(cc_payments),
      loans: sum_amounts(loan_payments),
      total: sum_amounts(payments),
      details: payments.map { |t| payment_detail(t) }
    }
  end

  # Money moved to savings accounts
  def savings_contributions_total
    transfers_to_account_type("Depository", subtype: "savings")
  end

  # Money moved to investment accounts
  def investment_contributions_total
    transfers_to_account_type("Investment") + transfers_to_account_type("Crypto")
  end

  # Sustainability metrics
  def sustainability_metrics
    income = income_total
    debt_total = debt_payments_breakdown[:total]
    lifestyle = lifestyle_expenses_total

    total_outflow = lifestyle + debt_total

    # What percentage of debt payments are covered by income?
    debt_coverage = income.positive? ? (income / total_outflow * 100).round(1) : 0

    # Are they drawing down savings/investments to fund lifestyle + debt?
    funding_gap = total_outflow - income
    funding_gap = 0 if funding_gap.negative?

    # Analyze where the funding gap is coming from
    funding_sources = analyze_funding_sources(funding_gap)

    {
      income: income,
      total_outflow: total_outflow,
      funding_gap: funding_gap,
      coverage_percent: debt_coverage,
      sustainable: funding_gap.zero?,
      funding_sources: funding_sources,
      insights: generate_insights(income, lifestyle, debt_total, funding_gap, funding_sources)
    }
  end

  private

  def debt_payment_transactions
    Transaction
      .joins(:entry)
      .joins(entry: :account)
      .where(accounts: { family_id: family.id, status: %w[draft active] })
      .where(entries: { entryable_type: "Transaction", excluded: false, date: period.date_range })
      .where(kind: %w[cc_payment loan_payment])
      .includes(entry: :account)
  end

  def sum_amounts(transactions)
    transactions.sum { |t| t.entry.amount.abs }
  end

  def payment_detail(transaction)
    transfer = Transfer.find_by(outflow_transaction_id: transaction.id)
    {
      date: transaction.entry.date,
      amount: transaction.entry.amount.abs,
      to_account: transfer&.to_account&.name || "Unknown",
      from_account: transfer&.from_account&.name || "Unknown",
      kind: transaction.kind
    }
  end

  def transfers_to_account_type(accountable_type, subtype: nil)
    # Find outflow transactions where destination is this account type
    query = Transfer
      .joins(inflow_transaction: { entry: :account })
      .joins(outflow_transaction: :entry)
      .where(accounts: { family_id: family.id, accountable_type: accountable_type })
      .where(entries: { date: period.date_range })

    if subtype
      query = query.where(accounts: { subtype: subtype })
    end

    query.sum("ABS(entries.amount)")
  end

  def analyze_funding_sources(funding_gap)
    return {} if funding_gap.zero?

    # Look for inflows to checking/primary accounts from savings/investments
    # These represent "drawdowns" that funded the gap

    sources = {
      savings_drawdown: 0,
      investment_liquidation: 0,
      crypto_liquidation: 0,
      other: 0
    }

    # Find transfers INTO checking/depository accounts FROM savings/investments
    inflows_from_savings = transfers_from_account_type("Depository", to_type: "Depository")
    inflows_from_investments = transfers_from_account_type("Investment", to_type: "Depository")
    inflows_from_crypto = transfers_from_account_type("Crypto", to_type: "Depository")

    sources[:savings_drawdown] = [inflows_from_savings, funding_gap].min
    remaining = funding_gap - sources[:savings_drawdown]

    if remaining.positive?
      sources[:investment_liquidation] = [inflows_from_investments, remaining].min
      remaining -= sources[:investment_liquidation]
    end

    if remaining.positive?
      sources[:crypto_liquidation] = [inflows_from_crypto, remaining].min
      remaining -= sources[:crypto_liquidation]
    end

    sources[:other] = remaining if remaining.positive?

    sources
  end

  def transfers_from_account_type(from_type, to_type:)
    Transfer
      .joins(outflow_transaction: { entry: :account })
      .joins("JOIN entries inflow_entries ON inflow_entries.entryable_id = transfers.inflow_transaction_id")
      .joins("JOIN accounts inflow_accounts ON inflow_accounts.id = inflow_entries.account_id")
      .where(accounts: { family_id: family.id, accountable_type: from_type })
      .where(inflow_accounts: { accountable_type: to_type })
      .where(entries: { date: period.date_range })
      .sum("ABS(entries.amount)")
  end

  def generate_insights(income, lifestyle, debt_total, funding_gap, funding_sources)
    insights = []

    if funding_gap.positive?
      if funding_sources[:savings_drawdown].positive?
        insights << {
          type: :warning,
          message: "Drawing #{format_money(funding_sources[:savings_drawdown])} from savings to cover expenses"
        }
      end

      if funding_sources[:investment_liquidation].positive? || funding_sources[:crypto_liquidation].positive?
        liquidation = funding_sources[:investment_liquidation] + funding_sources[:crypto_liquidation]
        insights << {
          type: :alert,
          message: "Liquidating #{format_money(liquidation)} from investments to cover expenses"
        }
      end

      insights << {
        type: :critical,
        message: "Spending #{format_money(funding_gap)} more than income this period"
      }
    else
      surplus = income - lifestyle - debt_total
      if surplus.positive?
        insights << {
          type: :positive,
          message: "#{format_money(surplus)} surplus after expenses and debt payments"
        }
      end
    end

    # Debt payment analysis
    if debt_total.positive?
      debt_percent = (debt_total / income * 100).round(1) rescue 0
      if debt_percent > 50
        insights << {
          type: :warning,
          message: "#{debt_percent}% of income going to debt payments"
        }
      end
    end

    insights
  end

  def format_money(amount)
    Money.new(amount, family.currency).format
  end
end
