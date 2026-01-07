require "test_helper"

class Merchant::MergesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @family = families(:dylan_family)
  end

  test "new returns available merchants for merge" do
    merchant1 = @family.merchants.create!(name: "Merchant A", color: "#ff0000")
    merchant2 = @family.merchants.create!(name: "Merchant B", color: "#00ff00")

    get new_merchant_merge_path, params: { merchant_ids: [ merchant1.id, merchant2.id ] }
    assert_response :success
  end

  test "create merges merchants into target" do
    merchant1 = @family.merchants.create!(name: "Merchant A", color: "#ff0000")
    merchant2 = @family.merchants.create!(name: "Merchant B", color: "#00ff00")
    target = @family.merchants.create!(name: "Target Merchant", color: "#0000ff")

    assert_difference "FamilyMerchant.count", -2 do
      post merchant_merge_path, params: {
        merchant_ids: [ merchant1.id, merchant2.id ],
        target_merchant_id: target.id
      }
    end

    assert_redirected_to family_merchants_path
  end

  test "cannot merge merchants from another family" do
    other_family = families(:empty)
    other_merchant = other_family.merchants.create!(name: "Other", color: "#000000")
    my_merchant = @family.merchants.create!(name: "Mine", color: "#ffffff")

    # The merchant_ids filter should only include merchants from current family
    # so other_merchant should be excluded
    post merchant_merge_path, params: {
      merchant_ids: [ my_merchant.id, other_merchant.id ],
      target_merchant_id: my_merchant.id
    }

    # Should only find 1 merchant (my_merchant), no merge happens
    assert_redirected_to family_merchants_path
  end

  test "cannot merge into target from another family" do
    other_family = families(:empty)
    other_merchant = other_family.merchants.create!(name: "Other Target", color: "#000000")
    my_merchant = @family.merchants.create!(name: "Mine", color: "#ffffff")

    assert_raises(ActiveRecord::RecordNotFound) do
      post merchant_merge_path, params: {
        merchant_ids: [ my_merchant.id ],
        target_merchant_id: other_merchant.id
      }
    end
  end
end
