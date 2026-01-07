class Merchant::MergesController < ApplicationController
  before_action :set_merchants

  def new
    @available_merchants = Current.family.merchants.alphabetically.where.not(id: @merchants.map(&:id))
  end

  def create
    target_merchant = Current.family.merchants.find(params[:target_merchant_id])

    merged_count = 0
    ApplicationRecord.transaction do
      @merchants.each do |merchant|
        next if merchant == target_merchant
        merchant.replace_and_destroy!(target_merchant)
        merged_count += 1
      end
    end

    redirect_to family_merchants_path, notice: t(".success", count: merged_count, target: target_merchant.name)
  end

  private
    def set_merchants
      @merchants = Current.family.merchants.where(id: merchant_ids)
    end

    # Accepts merchant_ids from both formats:
    # - merchant_ids[] (direct params)
    # - entry_ids[] (from bulk-select controller with empty scope)
    def merchant_ids
      params[:merchant_ids] || params[:entry_ids] || []
    end
end
