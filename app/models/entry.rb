class Entry < ApplicationRecord
  include Monetizable, Enrichable

  monetize :amount

  belongs_to :account
  belongs_to :transfer, optional: true
  belongs_to :import, optional: true

  delegated_type :entryable, types: Entryable::TYPES, dependent: :destroy
  accepts_nested_attributes_for :entryable

  validates :date, :name, :amount, :currency, presence: true
  validates :date, uniqueness: { scope: [ :account_id, :entryable_type ] }, if: -> { valuation? }
  validates :date, comparison: { greater_than: -> { min_supported_date } }
  validates :external_id, uniqueness: { scope: [ :account_id, :source ] }, if: -> { external_id.present? && source.present? }

  scope :visible, -> {
    joins(:account).where(accounts: { status: [ "draft", "active" ] })
  }

  scope :chronological, -> {
    order(
      date: :asc,
      Arel.sql("CASE WHEN entries.entryable_type = 'Valuation' THEN 1 ELSE 0 END") => :asc,
      created_at: :asc
    )
  }

  scope :reverse_chronological, -> {
    order(
      date: :desc,
      Arel.sql("CASE WHEN entries.entryable_type = 'Valuation' THEN 1 ELSE 0 END") => :desc,
      created_at: :desc
    )
  }

  def classification
    amount.negative? ? "income" : "expense"
  end

  def lock_saved_attributes!
    super
    entryable.lock_saved_attributes!
  end

  def sync_account_later
    sync_start_date = [ date_previously_was, date ].compact.min unless destroyed?
    account.sync_later(window_start_date: sync_start_date)
  end

  def entryable_name_short
    entryable_type.demodulize.underscore
  end

  def balance_trend(entries, balances)
    Balance::TrendCalculator.new(self, entries, balances).trend
  end

  def linked?
    external_id.present?
  end

  class << self
    def search(params)
      EntrySearch.new(params).build_query(all)
    end

    # arbitrary cutoff date to avoid expensive sync operations
    def min_supported_date
      30.years.ago.to_date
    end

    def bulk_update!(bulk_update_params)
      bulk_attributes = {
        date: bulk_update_params[:date],
        notes: bulk_update_params[:notes],
        entryable_attributes: {
          category_id: bulk_update_params[:category_id],
          merchant_id: bulk_update_params[:merchant_id],
          tag_ids: bulk_update_params[:tag_ids]
        }.compact_blank
      }.compact_blank

      return 0 if bulk_attributes.blank?

      transaction do
        all.each do |entry|
          bulk_attributes[:entryable_attributes][:id] = entry.entryable_id if bulk_attributes[:entryable_attributes].present?
          entry.update! bulk_attributes

          entry.lock_saved_attributes!
          entry.entryable.lock_attr!(:tag_ids) if entry.transaction? && entry.transaction.tags.any?
        end
      end

      all.size
    end

    # Merge multiple entries into a single primary entry. The primary entry
    # is kept and updated with the provided attributes, while duplicate entries
    # are destroyed. Returns the primary entry.
    #
    # @param primary_entry_id [String] The ID of the entry to keep
    # @param merge_params [Hash] Optional attributes to update on the primary entry
    # @option merge_params [Boolean] :sum_amounts If true, sum all amounts into the primary
    # @return [Entry] The merged primary entry
    def bulk_merge!(primary_entry_id, merge_params = {})
      # Eager load associations to prevent N+1 queries
      entries = all.includes(:account, entryable: :tags).to_a
      return nil if entries.empty?

      primary_entry = entries.find { |e| e.id.to_s == primary_entry_id.to_s }
      raise ActiveRecord::RecordNotFound, "Primary entry not found in selection" unless primary_entry

      duplicates = entries.reject { |e| e.id == primary_entry.id }
      return primary_entry if duplicates.empty?

      transaction do
        if merge_params[:sum_amounts]
          total_amount = entries.sum(&:amount)
          primary_entry.update!(amount: total_amount)
        end

        # Collect unique tags from all entries being merged
        if primary_entry.transaction?
          all_tag_ids = entries.flat_map { |e| e.transaction? ? e.transaction.tag_ids : [] }.uniq
          if all_tag_ids.any?
            primary_entry.transaction.update!(tag_ids: all_tag_ids)
            primary_entry.transaction.lock_attr!(:tag_ids)
          end
        end

        # Destroy duplicates and sync their accounts
        affected_accounts = duplicates.map(&:account).uniq
        duplicates.each(&:destroy!)
        affected_accounts.each(&:sync_later)

        primary_entry.sync_account_later
      end

      primary_entry
    end
  end
end
