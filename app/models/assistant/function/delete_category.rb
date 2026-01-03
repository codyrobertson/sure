class Assistant::Function::DeleteCategory < Assistant::Function
  class << self
    def name
      "delete_category"
    end

    def description
      <<~INSTRUCTIONS
        Use this to delete a category.

        When a category is deleted:
        - Transactions in that category become uncategorized
        - Subcategories become top-level categories

        You can delete multiple categories at once by providing an array of names.

        Example - delete a single category:
        ```
        delete_category({
          names: ["Old Category"]
        })
        ```

        Example - delete multiple categories:
        ```
        delete_category({
          names: ["Shopping/Online Retail", "Shopping/Convenience", "Old Stuff"]
        })
        ```

        IMPORTANT: Always confirm with the user before deleting categories,
        especially if they contain transactions.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: ["names"],
      properties: {
        names: {
          type: "array",
          description: "Names of the categories to delete",
          items: { type: "string" }
        }
      }
    )
  end

  def call(params = {})
    names = Array(params["names"])
    return { error: "No category names provided" } if names.empty?

    report_progress("Finding categories to delete...")

    results = {
      deleted: [],
      not_found: [],
      transactions_uncategorized: 0
    }

    names.each do |name|
      # Try exact match first, then case-insensitive
      category = family.categories.find_by(name: name) ||
                 family.categories.find_by("LOWER(name) = ?", name.downcase)

      if category.nil?
        results[:not_found] << name
        next
      end

      # Count affected transactions before deletion
      transaction_count = category.transactions.count
      results[:transactions_uncategorized] += transaction_count

      report_progress("Deleting '#{category.name}' (#{transaction_count} transactions)...")
      category.destroy!
      results[:deleted] << category.name
    end

    broadcast_data_changed if results[:deleted].any?

    {
      success: results[:deleted].any?,
      deleted_count: results[:deleted].size,
      deleted: results[:deleted],
      not_found: results[:not_found].presence,
      transactions_uncategorized: results[:transactions_uncategorized]
    }.compact
  rescue ActiveRecord::RecordNotDestroyed => e
    { error: "Failed to delete category: #{e.message}" }
  end
end
