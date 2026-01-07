class Transactions::MergesController < ApplicationController
  def new
    @entries = Current.family.entries.where(id: entry_ids).includes(:account, entryable: [ :category, :merchant, :tags ])
  end

  def create
    entries = Current.family.entries.where(id: merge_params[:entry_ids])

    merged_entry = entries.bulk_merge!(
      merge_params[:primary_entry_id],
      sum_amounts: merge_params[:sum_amounts] == "1"
    )

    redirect_back_or_to transactions_path, notice: t(".success", count: merge_params[:entry_ids].size - 1)
  end

  private
    # Accepts entry_ids from both formats:
    # - merge[entry_ids][] (from bulk-select controller with scope "merge")
    # - entry_ids[] (direct params)
    def entry_ids
      params.dig(:merge, :entry_ids) || params[:entry_ids] || []
    end

    def merge_params
      params.require(:merge).permit(:primary_entry_id, :sum_amounts, entry_ids: [])
    end
end
