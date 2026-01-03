class Assistant::Function::CreateRule < Assistant::Function
  class << self
    def name
      "create_rule"
    end

    def description
      <<~INSTRUCTIONS
        Use this to create an automation rule that automatically processes transactions.

        Rules have CONDITIONS (when to apply) and ACTIONS (what to do).

        ## Condition Types:
        - transaction_name: Match transaction name/description (operators: like, =, is_null)
        - transaction_amount: Match transaction amount (operators: >, >=, <, <=, =)
        - transaction_merchant: Match merchant name (operators: =, is_null)
        - transaction_category: Match category (operators: =, is_null)

        ## Action Types:
        - set_transaction_category: Set the category (value = category name)
        - set_transaction_tags: Add tags (value = tag name)
        - set_transaction_merchant: Set merchant (value = merchant name)
        - set_transaction_name: Rename transaction (value = new name)

        Example - categorize Starbucks transactions:
        ```
        create_rule({
          name: "Starbucks to Food & Drink",
          conditions: [
            { type: "transaction_name", operator: "like", value: "starbucks" }
          ],
          actions: [
            { type: "set_transaction_category", value: "Food & Drink" }
          ]
        })
        ```

        Example - tag large purchases:
        ```
        create_rule({
          name: "Tag large purchases",
          conditions: [
            { type: "transaction_amount", operator: ">", value: "500" }
          ],
          actions: [
            { type: "set_transaction_tags", value: "Large Purchase" }
          ]
        })
        ```

        IMPORTANT: After creating a rule, inform the user how many transactions it would affect.
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: ["conditions", "actions"],
      properties: {
        name: {
          type: "string",
          description: "Name of the rule (optional, will auto-generate if not provided)"
        },
        conditions: {
          type: "array",
          description: "Conditions that must match for the rule to apply",
          items: {
            type: "object",
            properties: {
              type: {
                type: "string",
                enum: ["transaction_name", "transaction_amount", "transaction_merchant", "transaction_category"],
                description: "Type of condition"
              },
              operator: {
                type: "string",
                enum: ["like", "=", ">", ">=", "<", "<=", "is_null"],
                description: "Comparison operator"
              },
              value: {
                type: "string",
                description: "Value to compare against"
              }
            },
            required: ["type", "operator"]
          },
          minItems: 1
        },
        actions: {
          type: "array",
          description: "Actions to perform when conditions match",
          items: {
            type: "object",
            properties: {
              type: {
                type: "string",
                enum: ["set_transaction_category", "set_transaction_tags", "set_transaction_merchant", "set_transaction_name"],
                description: "Type of action"
              },
              value: {
                type: "string",
                description: "Value for the action (category name, tag name, merchant name, or new name)"
              }
            },
            required: ["type", "value"]
          },
          minItems: 1
        },
        apply_immediately: {
          type: "boolean",
          description: "If true, apply the rule to existing transactions immediately. Defaults to false."
        },
        include_past_transactions: {
          type: "boolean",
          description: "If true, the rule will also match past/historical transactions. Defaults to true."
        }
      }
    )
  end

  def call(params = {})
    report_progress("Setting up automation rule...")

    conditions_attrs = build_conditions(params["conditions"])
    actions_attrs = build_actions(params["actions"])

    return actions_attrs if actions_attrs.is_a?(Hash) && actions_attrs[:error]

    # Default to including past transactions unless explicitly set to false
    include_past = params["include_past_transactions"] != false
    effective_date = include_past ? Date.new(1970, 1, 1) : Date.current

    report_progress("Creating rule and checking affected transactions...")

    rule = family.rules.create!(
      name: params["name"],
      resource_type: "transaction",
      effective_date: effective_date,
      conditions_attributes: conditions_attrs,
      actions_attributes: actions_attrs
    )
    broadcast_data_changed

    affected_count = rule.affected_resource_count

    result = {
      success: true,
      rule_id: rule.id,
      rule_name: rule.name || rule.primary_condition_title,
      affected_transactions: affected_count
    }

    if params["apply_immediately"] && affected_count > 0
      modified = rule.apply
      result[:applied] = true
      result[:modified_count] = modified.is_a?(Hash) ? modified[:modified_count] : modified
      broadcast_data_changed
    end

    result
  rescue ActiveRecord::RecordInvalid => e
    { error: e.message }
  end

  private

  def build_conditions(conditions)
    conditions.map do |cond|
      {
        condition_type: cond["type"],
        operator: cond["operator"],
        value: cond["value"]
      }
    end
  end

  def build_actions(actions)
    actions.map do |action|
      action_value = resolve_action_value(action["type"], action["value"])
      return { error: action_value[:error] } if action_value.is_a?(Hash) && action_value[:error]

      {
        action_type: action["type"],
        value: action_value
      }
    end
  end

  def resolve_action_value(action_type, value)
    case action_type
    when "set_transaction_category"
      category = family.categories.find_by("LOWER(name) = ?", value.downcase)
      return { error: "Category '#{value}' not found. Create it first using create_category." } unless category
      category.id.to_s
    when "set_transaction_tags"
      tag = family.tags.find_by("LOWER(name) = ?", value.downcase)
      return { error: "Tag '#{value}' not found. Create it first using create_tag." } unless tag
      tag.id.to_s
    when "set_transaction_merchant"
      merchant = family.merchants.find_by("LOWER(name) = ?", value.downcase)
      # For merchants, we can create if missing since it's simpler
      unless merchant
        merchant = family.merchants.create!(name: value)
      end
      merchant.id.to_s
    when "set_transaction_name"
      value
    else
      value
    end
  end
end
