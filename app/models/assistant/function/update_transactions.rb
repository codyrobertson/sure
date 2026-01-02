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
        2. Update transactions matching a search term

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

        Example - rename and add notes:
        ```
        update_transactions({
          search: "uber",
          name: "Uber Ride",
          notes: "Transportation"
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
    entry_ids = transactions.limit(MAX_BATCH_SIZE).pluck(:entry_id)
    updated_count = Entry.where(id: entry_ids).update_all(update_attrs)

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
    scope = family.transactions.joins(:entry).includes(:merchant)

    if params["transaction_ids"].present?
      scope = scope.where(id: params["transaction_ids"])
    end

    if params["search"].present?
      sanitized_ilike = "%#{ActiveRecord::Base.sanitize_sql_like(params['search'])}%"
      # Use tsvector full-text search on entries (uses GIN index) plus ILIKE for merchant
      scope = scope.left_joins(:merchant).where(
        "entries.search_vector @@ plainto_tsquery('simple', :term) OR merchants.name ILIKE :ilike_term",
        term: params["search"],
        ilike_term: sanitized_ilike
      )
    end

    scope
  end
end
