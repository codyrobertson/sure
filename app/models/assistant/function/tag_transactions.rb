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

  def call(params = {})
    transactions = find_transactions(params)

    return { error: "No transactions found matching criteria" } if transactions.empty?

    tag = find_or_create_tag(params)

    return { error: "Tag '#{params['tag_name']}' not found. Set create_if_missing to true to create it." } if tag.nil?

    tagged_count = 0
    transactions.each do |transaction|
      unless transaction.tags.include?(tag)
        transaction.tags << tag
        tagged_count += 1
      end
    end

    {
      success: true,
      tagged_count: tagged_count,
      tag_name: tag.name,
      tag_id: tag.id
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
