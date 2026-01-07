require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  include EntriesTestHelper

  test "pending? is true when extra.simplefin.pending is truthy" do
    transaction = Transaction.new(extra: { "simplefin" => { "pending" => true } })

    assert transaction.pending?
  end

  test "pending? is true when extra.plaid.pending is truthy" do
    transaction = Transaction.new(extra: { "plaid" => { "pending" => "true" } })

    assert transaction.pending?
  end

  test "pending? is false when no provider pending metadata is present" do
    transaction = Transaction.new(extra: { "plaid" => { "pending" => false } })

    assert_not transaction.pending?
  end

  test "enriched_by_rule? returns false when no rule enrichments exist" do
    family = families(:empty)
    account = family.accounts.create!(name: "Test", balance: 1000, currency: "USD", accountable: Depository.new)
    entry = create_transaction(date: Date.current, account: account)

    assert_not entry.transaction.enriched_by_rule?
  end

  test "enriched_by_rule? returns true when rule enrichment exists" do
    family = families(:empty)
    account = family.accounts.create!(name: "Test", balance: 1000, currency: "USD", accountable: Depository.new)
    category = family.categories.create!(name: "Test Category")
    entry = create_transaction(date: Date.current, account: account)

    rule = family.rules.create!(
      resource_type: "transaction",
      conditions: [ Rule::Condition.new(condition_type: "transaction_name", operator: "like", value: entry.name) ],
      actions: [ Rule::Action.new(action_type: "set_transaction_category", value: category.id) ]
    )

    rule.apply

    entry.reload
    assert entry.transaction.enriched_by_rule?
  end

  test "category_rule returns the rule that set the category" do
    family = families(:empty)
    account = family.accounts.create!(name: "Test", balance: 1000, currency: "USD", accountable: Depository.new)
    category = family.categories.create!(name: "Test Category")
    entry = create_transaction(date: Date.current, account: account)

    rule = family.rules.create!(
      resource_type: "transaction",
      name: "Auto-categorize rule",
      conditions: [ Rule::Condition.new(condition_type: "transaction_name", operator: "like", value: entry.name) ],
      actions: [ Rule::Action.new(action_type: "set_transaction_category", value: category.id) ]
    )

    rule.apply

    entry.reload
    assert_equal rule, entry.transaction.category_rule
  end

  test "category_rule returns nil when category was not set by rule" do
    family = families(:empty)
    account = family.accounts.create!(name: "Test", balance: 1000, currency: "USD", accountable: Depository.new)
    category = family.categories.create!(name: "Test Category")
    entry = create_transaction(date: Date.current, account: account, category: category)

    assert_nil entry.transaction.category_rule
  end

  test "enriching_rules returns all rules that enriched the transaction" do
    family = families(:empty)
    account = family.accounts.create!(name: "Test", balance: 1000, currency: "USD", accountable: Depository.new)
    category = family.categories.create!(name: "Test Category")
    merchant = family.merchants.create!(name: "Test Merchant", type: "FamilyMerchant")
    entry = create_transaction(date: Date.current, account: account)

    category_rule = family.rules.create!(
      resource_type: "transaction",
      name: "Category rule",
      conditions: [ Rule::Condition.new(condition_type: "transaction_name", operator: "like", value: entry.name) ],
      actions: [ Rule::Action.new(action_type: "set_transaction_category", value: category.id) ]
    )

    merchant_rule = family.rules.create!(
      resource_type: "transaction",
      name: "Merchant rule",
      conditions: [ Rule::Condition.new(condition_type: "transaction_name", operator: "like", value: entry.name) ],
      actions: [ Rule::Action.new(action_type: "set_transaction_merchant", value: merchant.id) ]
    )

    category_rule.apply
    merchant_rule.apply

    entry.reload
    enriching_rules = entry.transaction.enriching_rules

    assert_includes enriching_rules, category_rule
    assert_includes enriching_rules, merchant_rule
  end
end
