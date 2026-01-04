class Assistant::Function::UpdateCategory < Assistant::Function
  class << self
    def name
      "update_category"
    end

    def description
      <<~INSTRUCTIONS
        Use this to update an existing category's properties.

        You can:
        - Set or change the parent category (make it a subcategory)
        - Remove the parent (make it a top-level category)
        - Change the icon
        - Rename the category

        Example - make a category a subcategory:
        ```
        update_category({
          name: "Online Retail",
          parent_name: "Shopping"
        })
        ```

        Example - update multiple categories to have the same parent:
        ```
        update_category({
          names: ["Online Retail", "Convenience", "Other Purchases"],
          parent_name: "Shopping"
        })
        ```

        Example - remove parent (make top-level):
        ```
        update_category({
          name: "Some Category",
          parent_name: null
        })
        ```

        Example - change icon:
        ```
        update_category({
          name: "Groceries",
          icon: "shopping-cart"
        })
        ```

        Example - rename a category:
        ```
        update_category({
          name: "Old Name",
          new_name: "New Name"
        })
        ```
      INSTRUCTIONS
    end
  end

  def params_schema
    build_schema(
      required: [],
      properties: {
        name: {
          type: "string",
          description: "Name of the category to update (use this OR names, not both)"
        },
        names: {
          type: "array",
          description: "Names of multiple categories to update with the same changes",
          items: { type: "string" }
        },
        parent_name: {
          type: ["string", "null"],
          description: "Name of the new parent category. Use null to remove parent and make top-level."
        },
        new_name: {
          type: "string",
          description: "New name for the category (only works with single category, not bulk)"
        },
        icon: {
          type: "string",
          description: "New Lucide icon name for the category"
        }
      }
    )
  end

  def call(params = {})
    # Get list of category names to update
    names = if params["names"].present?
      Array(params["names"])
    elsif params["name"].present?
      [params["name"]]
    else
      return { error: "Must provide 'name' or 'names' of categories to update" }
    end

    # Find parent if specified
    parent = nil
    set_parent = params.key?("parent_name")
    if set_parent && params["parent_name"].present?
      parent = family.categories.find_by("LOWER(name) = ?", params["parent_name"].downcase)
      return { error: "Parent category '#{params['parent_name']}' not found" } unless parent
    end

    report_progress("Updating #{names.size} #{names.size == 1 ? 'category' : 'categories'}...")

    results = {
      updated: [],
      not_found: [],
      errors: []
    }

    names.each do |name|
      category = family.categories.find_by("LOWER(name) = ?", name.downcase)

      if category.nil?
        results[:not_found] << name
        next
      end

      # Prevent circular parent reference
      if parent && (parent.id == category.id || parent.parent_id == category.id)
        results[:errors] << "Cannot set '#{parent.name}' as parent of '#{category.name}' (circular reference)"
        next
      end

      updates = {}
      updates[:parent_id] = parent&.id if set_parent
      updates[:lucide_icon] = params["icon"] if params["icon"].present?
      updates[:name] = params["new_name"] if params["new_name"].present? && names.size == 1

      if updates.any?
        category.update!(updates)
        results[:updated] << {
          name: category.reload.name,
          parent: category.parent&.name,
          icon: category.lucide_icon
        }
      end
    end

    broadcast_data_changed if results[:updated].any?

    response = {
      success: results[:updated].any?,
      updated_count: results[:updated].size,
      updated: results[:updated]
    }
    response[:not_found] = results[:not_found] if results[:not_found].any?
    response[:errors] = results[:errors] if results[:errors].any?
    response
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end
end
