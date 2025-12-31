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

  def call(params = {})
    transactions = find_transactions(params)

    return { error: "No transactions found matching criteria" } if transactions.empty?

    category = find_or_create_category(params)

    return { error: "Category '#{params['category_name']}' not found. Set create_if_missing to true to create it." } if category.nil?

    updated_count = transactions.update_all(category_id: category.id)

    {
      success: true,
      updated_count: updated_count,
      category_name: category.name,
      category_id: category.id
    }
  end

  private

  def find_transactions(params)
    scope = family.transactions.joins(:entry).includes(:merchant)

    if params["transaction_ids"].present?
      scope = scope.where(id: params["transaction_ids"])
    end

    if params["search"].present?
      search_term = "%#{params['search']}%"
      # Search in entry name, merchant name, and notes
      scope = scope.left_joins(:merchant).where(
        "entries.name ILIKE :term OR merchants.name ILIKE :term OR entries.notes ILIKE :term",
        term: search_term
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
