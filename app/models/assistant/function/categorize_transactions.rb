class Assistant::Function::CategorizeTransactions < Assistant::Function
  class << self
    def name
      "categorize_transactions"
    end

    def description
      <<~INSTRUCTIONS
        Use this to categorize one or more transactions.

        You can either:
        1. Assign an existing category by name
        2. Create a new category on the fly by providing a name that doesn't exist

        Example - categorize specific transactions:
        ```
        categorize_transactions({
          transaction_ids: [1, 2, 3],
          category_name: "Food & Drink"
        })
        ```

        Example - categorize by search criteria:
        ```
        categorize_transactions({
          search: "starbucks",
          category_name: "Food & Drink"
        })
        ```

        IMPORTANT: Always confirm with the user before categorizing large numbers of transactions.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: ["category_name"],
      properties: {
        transaction_ids: {
          type: "array",
          description: "Specific transaction IDs to categorize",
          items: { type: "integer" }
        },
        search: {
          type: "string",
          description: "Search term to find transactions to categorize (by name/merchant)"
        },
        category_name: {
          type: "string",
          description: "Name of the category to assign (existing or new)"
        },
        create_if_missing: {
          type: "boolean",
          description: "If true, create the category if it doesn't exist. Defaults to false."
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
    report_progress("Found #{total_matching} transactions, applying category...")

    category = find_or_create_category(params)

    return { error: "Category '#{params['category_name']}' not found. Set create_if_missing to true to create it." } if category.nil?

    # Limit to batch size to prevent timeouts
    batch = transactions.limit(MAX_BATCH_SIZE)
    report_progress("Categorizing #{[total_matching, MAX_BATCH_SIZE].min} transactions as '#{category.name}'...")
    updated_count = batch.update_all(category_id: category.id)

    result = {
      success: true,
      updated_count: updated_count,
      category_name: category.name,
      category_id: category.id
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
    scope = family.transactions.joins(:entry)

    if params["transaction_ids"].present?
      scope = scope.where(id: params["transaction_ids"])
    end

    if params["search"].present?
      sanitized_ilike = "%#{ActiveRecord::Base.sanitize_sql_like(params['search'])}%"
      # Use tsvector full-text search (fast, uses GIN index) plus ILIKE fallback for merchant
      scope = scope.left_joins(:merchant).where(
        "entries.search_vector @@ plainto_tsquery('simple', :term) OR merchants.name ILIKE :ilike_term",
        term: params["search"],
        ilike_term: sanitized_ilike
      )
    end

    scope
  end

  def find_or_create_category(params)
    category_name = params["category_name"]
    category = family.categories.find_by("LOWER(name) = ?", category_name.downcase)

    if category.nil? && params["create_if_missing"]
      category = family.categories.create!(
        name: category_name,
        classification: "expense",
        color: Category::COLORS.sample,
        lucide_icon: "tag"
      )
    end

    category
  end
end
