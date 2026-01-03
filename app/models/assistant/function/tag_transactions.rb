class Assistant::Function::TagTransactions < Assistant::Function
  class << self
    def name
      "tag_transactions"
    end

    def description
      <<~INSTRUCTIONS
        Use this to add tags to one or more transactions.

        Unlike categories, transactions can have multiple tags.
        You can either use an existing tag or create a new one.

        Example - tag specific transactions:
        ```
        tag_transactions({
          transaction_ids: [1, 2, 3],
          tag_name: "Tax Deductible"
        })
        ```

        Example - tag by search criteria:
        ```
        tag_transactions({
          search: "uber",
          tag_name: "Business"
        })
        ```

        Example - tag only income (refunds) from Amazon:
        ```
        tag_transactions({
          search: "amazon",
          types: ["income"],
          tag_name: "Refund"
        })
        ```

        IMPORTANT: Always confirm with the user before tagging large numbers of transactions.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: ["tag_name"],
      properties: {
        transaction_ids: {
          type: "array",
          description: "Specific transaction IDs to tag",
          items: { type: "integer" }
        },
        search: {
          type: "string",
          description: "Search term to find transactions to tag (by name/merchant)"
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
        start_date: {
          type: "string",
          description: "Filter transactions on or after this date (YYYY-MM-DD)"
        },
        end_date: {
          type: "string",
          description: "Filter transactions on or before this date (YYYY-MM-DD)"
        },
        tag_name: {
          type: "string",
          description: "Name of the tag to apply (existing or new)"
        },
        create_if_missing: {
          type: "boolean",
          description: "If true, create the tag if it doesn't exist. Defaults to false."
        }
      }
    )
  end

  MAX_BATCH_SIZE = 500

  def call(params = {})
    report_progress("Finding matching transactions...")
    transactions = find_transactions(params)

    return { error: "No transactions found matching criteria" } if transactions.empty?

    total_matching = transactions.count
    report_progress("Found #{total_matching} transactions, preparing tag...")

    tag = find_or_create_tag(params)

    return { error: "Tag '#{params['tag_name']}' not found. Set create_if_missing to true to create it." } if tag.nil?

    # Get transaction IDs, limited to prevent timeouts
    report_progress("Processing up to #{MAX_BATCH_SIZE} transactions...")
    transaction_ids = transactions.limit(MAX_BATCH_SIZE).pluck(:id)

    # Find which transactions already have this tag
    existing_taggings = Tagging.where(tag_id: tag.id, taggable_type: "Transaction", taggable_id: transaction_ids).pluck(:taggable_id)

    # Only insert for transactions that don't already have the tag
    new_transaction_ids = transaction_ids - existing_taggings

    if new_transaction_ids.any?
      report_progress("Tagging #{new_transaction_ids.size} transactions with '#{tag.name}'...")
      # Bulk insert taggings
      tagging_records = new_transaction_ids.map do |txn_id|
        { tag_id: tag.id, taggable_type: "Transaction", taggable_id: txn_id, created_at: Time.current, updated_at: Time.current }
      end
      Tagging.insert_all(tagging_records)
      broadcast_data_changed
    end

    result = {
      success: true,
      tagged_count: new_transaction_ids.size,
      already_tagged: existing_taggings.size,
      tag_name: tag.name,
      tag_id: tag.id
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
    filters = params.slice("search", "types", "categories", "accounts", "merchants", "start_date", "end_date")
    scope = Transaction::Search.new(family, filters: filters).transactions_scope

    # Apply transaction_ids filter if specified (not supported by Transaction::Search)
    if params["transaction_ids"].present?
      scope = scope.where(id: params["transaction_ids"])
    end

    scope
  end

  def find_or_create_tag(params)
    tag_name = params["tag_name"]
    tag = family.tags.find_by("LOWER(name) = ?", tag_name.downcase)

    if tag.nil? && params["create_if_missing"]
      tag = family.tags.create!(
        name: tag_name,
        color: Tag::COLORS.sample
      )
    end

    tag
  end
end
