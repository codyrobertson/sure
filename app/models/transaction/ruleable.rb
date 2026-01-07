module Transaction::Ruleable
  extend ActiveSupport::Concern

  def eligible_for_category_rule?
    rules.joins(:actions).where(
      actions: {
        action_type: "set_transaction_category",
        value: category_id
      }
    ).empty?
  end

  # Returns true if this transaction has any attributes enriched by a rule
  def enriched_by_rule?
    rule_enrichments.any?
  end

  # Returns all DataEnrichment records for this transaction from rules
  def rule_enrichments
    @rule_enrichments ||= DataEnrichment.where(
      enrichable: self,
      source: "rule"
    )
  end

  # Returns the Rule that enriched the category, if any
  def category_rule
    enrichment = rule_enrichments.find_by(attribute_name: "category_id")
    return nil unless enrichment

    rule_id = enrichment.metadata&.dig("rule_id")
    return nil unless rule_id

    rules.find_by(id: rule_id)
  end

  # Returns all unique Rules that have enriched this transaction
  def enriching_rules
    rule_ids = rule_enrichments.filter_map { |e| e.metadata&.dig("rule_id") }.uniq
    rules.where(id: rule_ids)
  end

  private
    def rules
      entry.account.family.rules
    end
end
