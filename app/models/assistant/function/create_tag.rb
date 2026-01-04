class Assistant::Function::CreateTag < Assistant::Function
  class << self
    def name
      "create_tag"
    end

    def description
      <<~INSTRUCTIONS
        Use this to create a new tag for labeling transactions.

        Tags are flexible labels that can be applied to any transaction.
        Unlike categories (which are mutually exclusive), transactions can have multiple tags.

        Example:
        ```
        create_tag({
          name: "Tax Deductible"
        })
        ```

        Common tag ideas:
        - "Tax Deductible" - for tracking deductible expenses
        - "Reimbursable" - for expenses to be reimbursed
        - "Business" - for business-related transactions
        - "Vacation" - for trip-related spending
        - "Recurring" - for regular payments
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: ["name"],
      properties: {
        name: {
          type: "string",
          description: "Name of the tag to create"
        }
      }
    )
  end

  def call(params = {})
    report_progress("Creating tag '#{params['name']}'...")

    # Check if tag already exists
    existing = family.tags.find_by("LOWER(name) = ?", params["name"].downcase)
    return { error: "Tag '#{params['name']}' already exists", tag_id: existing.id } if existing

    tag = family.tags.create!(
      name: params["name"],
      color: Tag::COLORS.sample
    )
    broadcast_data_changed

    {
      success: true,
      tag_id: tag.id,
      name: tag.name
    }
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end
end
