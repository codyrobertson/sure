require "test_helper"

class EntryTest < ActiveSupport::TestCase
  def setup
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @entry1 = entries(:transaction)
    @entry2 = create_test_entry(amount: 20)
    @entry3 = create_test_entry(amount: 30)
  end

  test "bulk_merge! keeps primary entry and destroys duplicates" do
    entry_ids = [ @entry1.id, @entry2.id, @entry3.id ]
    entries = Entry.where(id: entry_ids)

    assert_difference "Entry.count", -2 do
      entries.bulk_merge!(@entry1.id)
    end

    assert @entry1.reload.present?
    assert_raises(ActiveRecord::RecordNotFound) { @entry2.reload }
    assert_raises(ActiveRecord::RecordNotFound) { @entry3.reload }
  end

  test "bulk_merge! returns nil for empty selection" do
    result = Entry.none.bulk_merge!("nonexistent")
    assert_nil result
  end

  test "bulk_merge! raises error when primary entry not in selection" do
    entry_ids = [ @entry2.id, @entry3.id ]
    entries = Entry.where(id: entry_ids)

    assert_raises(ActiveRecord::RecordNotFound) do
      entries.bulk_merge!(@entry1.id)
    end
  end

  test "bulk_merge! with sum_amounts sums all amounts into primary" do
    entry_ids = [ @entry1.id, @entry2.id, @entry3.id ]
    entries = Entry.where(id: entry_ids)

    original_amounts = entries.pluck(:amount)
    expected_sum = original_amounts.sum

    result = entries.bulk_merge!(@entry1.id, sum_amounts: true)

    assert_equal expected_sum, result.amount
  end

  test "bulk_merge! returns primary entry when only one entry selected" do
    entries = Entry.where(id: @entry1.id)

    assert_no_difference "Entry.count" do
      result = entries.bulk_merge!(@entry1.id)
      assert_equal @entry1, result
    end
  end

  test "bulk_merge! collects tags from all merged entries" do
    tag1 = @family.tags.create!(name: "Test Tag 1")
    tag2 = @family.tags.create!(name: "Test Tag 2")

    @entry1.transaction.update!(tag_ids: [ tag1.id ])
    @entry2.transaction.update!(tag_ids: [ tag2.id ])

    entry_ids = [ @entry1.id, @entry2.id ]
    entries = Entry.where(id: entry_ids)

    entries.bulk_merge!(@entry1.id)

    @entry1.reload
    assert_includes @entry1.transaction.tag_ids, tag1.id
    assert_includes @entry1.transaction.tag_ids, tag2.id
  end

  private

  def create_test_entry(amount:)
    transaction = Transaction.create!
    Entry.create!(
      name: "Test Entry",
      date: Date.current,
      amount: amount,
      currency: "USD",
      account: @account,
      entryable: transaction
    )
  end
end
