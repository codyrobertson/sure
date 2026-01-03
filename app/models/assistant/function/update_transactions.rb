class Assistant::Function::UpdateTransactions < Assistant::Function
  class << self
    def name
      "update_transactions"
    end

    def description
      <<~INSTRUCTIONS
        Use this to update the name or notes of one or more transactions.

        You can either:
        1. Update specific transactions by ID
        2. Update transactions matching filters (search, types, categories, etc.)

        Example - rename specific transactions:
        ```
        update_transactions({
          transaction_ids: [1, 2, 3],
          name: "Netflix Subscription"
        })
        ```

        Example - add notes to transactions by search:
        ```
        update_transactions({
          search: "AMZN",
          notes: "Amazon purchases - review for business expenses"
        })
        ```

        Example - rename only income (refunds) from a merchant:
        ```
        update_transactions({
          search: "amazon",
          types: ["income"],
          name: "Amazon Refund"
        })
        ```

        IMPORTANT: Always confirm with the user before updating large numbers of transactions.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        transaction_ids: {
          type: "array",
          description: "Specific transaction IDs to update",
          items: { type: "integer" }
        },
        search: {
          type: "string",
          description: "Search term to find transactions to update (by name/merchant)"
        },
        types: {
          type: "array",
          description: "Filter by transaction type: 'income' (positive cash flow like refunds/returns), 'expense' (purchases), or 'transfer'",
          items: { enum: %w[income expense transfer] }
        },
        categories: {
          type: "array",
          description: "Filter to transactions currently in these categories",
          items: { type: "string" }
        },
        accounts: {
          type: "array",
          description: "Filter by account names",
          items: { type: "string" }
        },
        merchants: {
          type: "array",
          description: "Filter by merchant names",
          items: { type: "string" }
        },
        tags: {
          type: "array",
          description: "Filter by tag names",
          items: { type: "string" }
        },
        start_date: {
          type: "string",
          description: "Filter transactions on or after this date (YYYY-MM-DD)"
        },
        end_date: {
          type: "string",
          description: "Filter transactions on or before this date (YYYY-MM-DD)"
        },
        name: {
          type: "string",
          description: "New name/description for the transactions"
        },
        notes: {
          type: "string",
          description: "Notes to add to the transactions"
        }
      }
    )
  end

  MAX_BATCH_SIZE = 500

  def call(params = {})
    # Validate at least one update field is provided
    if params["name"].blank? && params["notes"].blank?
      return { error: "Must provide at least one field to update (name or notes)" }
    end

    # Validate at least one selection criteria is provided
    if params["transaction_ids"].blank? && params["search"].blank?
      return { error: "Must provide transaction_ids or search term to find transactions" }
    end

    report_progress("Finding matching transactions...")
    transactions = find_transactions(params)

    return { error: "No transactions found matching criteria" } if transactions.empty?

    total_matching = transactions.count
    report_progress("Found #{total_matching} transactions...")

    # Build update attributes
    update_attrs = {}
    update_attrs[:name] = params["name"] if params["name"].present?
    update_attrs[:notes] = params["notes"] if params["notes"].present?

    # Update entries (which hold the name and notes) - limited to batch size
    updates_desc = update_attrs.keys.map(&:to_s).join(" and ")
    report_progress("Updating #{updates_desc} for #{[total_matching, MAX_BATCH_SIZE].min} transactions...")
    entry_ids = transactions.limit(MAX_BATCH_SIZE).pluck("entries.id")
    updated_count = Entry.where(id: entry_ids).update_all(update_attrs)
    broadcast_data_changed

    result = {
      success: true,
      updated_count: updated_count,
      updates_applied: update_attrs.keys.map(&:to_s)
    }

    # Warn if there are more transactions to process
    if total_matching > MAX_BATCH_SIZE
      result[:warning] = "Processed #{MAX_BATCH_SIZE} of #{total_matching} matching transactions. Run again to continue."
      result[:remaining] = total_matching - MAX_BATCH_SIZE
    end

    result
  end

  private

  def find_transactions(params)
    # Use Transaction::Search for consistent filtering
    filters = params.slice("search", "types", "categories", "accounts", "merchants", "tags", "start_date", "end_date")
    scope = Transaction::Search.new(family, filters: filters).transactions_scope

    # Apply transaction_ids filter if specified (not supported by Transaction::Search)
    if params["transaction_ids"].present?
      scope = scope.where(id: params["transaction_ids"])
    end

    scope
  end
end
