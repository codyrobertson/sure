require "test_helper"

class MerchantTest < ActiveSupport::TestCase
  def setup
    @family = families(:dylan_family)
    @amazon = merchants(:amazon)
    @netflix = merchants(:netflix)
  end

  test "replacing and destroying transfers transactions to target merchant" do
    transaction = transactions(:one)
    assert_equal @amazon, transaction.merchant

    @amazon.replace_and_destroy!(@netflix)

    assert_equal @netflix, transaction.reload.merchant
    assert_raises(ActiveRecord::RecordNotFound) { @amazon.reload }
  end

  test "replacing with nil should nullify merchant on transactions" do
    transaction = transactions(:one)
    assert_equal @amazon, transaction.merchant

    @amazon.replace_and_destroy!(nil)

    assert_nil transaction.reload.merchant
    assert_raises(ActiveRecord::RecordNotFound) { @amazon.reload }
  end

  test "cannot replace merchant with itself" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      @amazon.replace_and_destroy!(@amazon)
    end

    assert_match(/Replacement merchant cannot be the same/, error.message)
  end

  test "replace_and_destroy! transfers recurring transactions" do
    # Create a recurring transaction for amazon
    recurring = RecurringTransaction.create!(
      family: @family,
      merchant: @amazon,
      amount: 15.00,
      currency: "USD",
      expected_day_of_month: 15,
      status: "active"
    )

    @amazon.replace_and_destroy!(@netflix)

    assert_equal @netflix, recurring.reload.merchant
  end

  test "replace_and_destroy! destroys recurring transactions when replacement is nil" do
    # Create a recurring transaction for amazon
    recurring = RecurringTransaction.create!(
      family: @family,
      merchant: @amazon,
      amount: 15.00,
      currency: "USD",
      expected_day_of_month: 15,
      status: "active"
    )

    @amazon.replace_and_destroy!(nil)

    assert_raises(ActiveRecord::RecordNotFound) { recurring.reload }
  end
end
