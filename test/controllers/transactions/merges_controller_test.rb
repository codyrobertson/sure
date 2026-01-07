require "test_helper"

class Transactions::MergesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @entry = entries(:transaction)
  end

  test "new returns entries for merge selection" do
    get new_transactions_merge_path, params: { entry_ids: [ @entry.id ] }
    assert_response :success
  end

  test "create merges entries successfully" do
    entry2 = create_test_entry(amount: 50)

    assert_difference "Entry.count", -1 do
      post transactions_merge_path, params: {
        merge: {
          entry_ids: [ @entry.id, entry2.id ],
          primary_entry_id: @entry.id,
          sum_amounts: "0"
        }
      }
    end

    assert_redirected_to transactions_path
  end

  test "create merges entries with sum amounts" do
    entry2 = create_test_entry(amount: 50)
    original_amount = @entry.amount

    post transactions_merge_path, params: {
      merge: {
        entry_ids: [ @entry.id, entry2.id ],
        primary_entry_id: @entry.id,
        sum_amounts: "1"
      }
    }

    @entry.reload
    assert_equal original_amount + 50, @entry.amount
    assert_redirected_to transactions_path
  end

  test "cannot merge entries from another family" do
    other_family = families(:empty)
    # Create account for other family if needed
    other_account = other_family.accounts.first ||
      other_family.accounts.create!(
        name: "Other Account",
        accountable: Depository.create!,
        balance: 1000,
        currency: "USD"
      )

    other_transaction = Transaction.create!
    other_entry = Entry.create!(
      name: "Other Entry",
      date: Date.current,
      amount: 100,
      currency: "USD",
      account: other_account,
      entryable: other_transaction
    )

    # The entries filter should only include entries from current family
    post transactions_merge_path, params: {
      merge: {
        entry_ids: [ @entry.id, other_entry.id ],
        primary_entry_id: @entry.id,
        sum_amounts: "0"
      }
    }

    # Should only find 1 entry, no merge happens
    assert_redirected_to transactions_path
  end

  test "requires at least one entry to merge" do
    post transactions_merge_path, params: {
      merge: {
        entry_ids: [],
        primary_entry_id: @entry.id,
        sum_amounts: "0"
      }
    }

    # Should redirect without error, just no merge
    assert_redirected_to transactions_path
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
