class Merchant < ApplicationRecord
  TYPES = %w[FamilyMerchant ProviderMerchant].freeze

  has_many :transactions, dependent: :nullify
  has_many :recurring_transactions, dependent: :destroy

  validates :name, presence: true
  validates :type, inclusion: { in: TYPES }

  scope :alphabetically, -> { order(:name) }

  # Merge this merchant into the replacement merchant, transferring all
  # transactions and recurring transactions, then destroy self.
  # If replacement is nil, transactions will have merchant_id set to NULL
  # and recurring transactions will be destroyed.
  def replace_and_destroy!(replacement)
    transaction do
      raise ActiveRecord::RecordInvalid.new(self), "Replacement merchant cannot be the same as the merchant being destroyed" if replacement == self

      if replacement
        transactions.update_all(merchant_id: replacement.id)
        recurring_transactions.update_all(merchant_id: replacement.id)
      else
        transactions.update_all(merchant_id: nil)
        # recurring_transactions will be destroyed via dependent: :destroy
      end

      destroy!
    end
  end
end
