class SpendingAlert < ApplicationRecord
  belongs_to :family
  belongs_to :category, optional: true

  enum :alert_type, {
    category_anomaly: "category_anomaly",
    new_merchant: "new_merchant"
  }, prefix: true

  enum :severity, {
    warning: "warning",
    alert: "alert"
  }, prefix: true

  validates :alert_type, :severity, :period_start_date, :period_end_date, presence: true

  scope :active, -> { where(dismissed_at: nil) }
  scope :dismissed, -> { where.not(dismissed_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_severity, ->(sev) { where(severity: sev) }
  scope :for_period, ->(period) { where(period_start_date: period.start_date, period_end_date: period.end_date) }

  def active?
    dismissed_at.nil?
  end

  def dismissed?
    dismissed_at.present?
  end

  def dismiss!
    update!(dismissed_at: Time.current)
  end

  # Returns pre-serialized transaction data from metadata (not ActiveRecord objects).
  # This avoids N+1 queries - data is stored at alert creation time.
  def top_transactions
    metadata&.dig("top_transactions") || []
  end

  def merchant_name
    metadata&.dig("merchant_name")
  end

  def merchant_total_spent
    metadata&.dig("merchant_total_spent")
  end

  def merchant_transaction_count
    metadata&.dig("merchant_transaction_count")
  end

  # Create alerts from AnomalyDetector analysis
  def self.create_from_anomaly_analysis(family, period, analysis)
    alerts_created = []

    # Create alerts for category anomalies
    analysis[:anomalies]&.each do |anomaly|
      alert = find_or_initialize_by(
        family: family,
        alert_type: :category_anomaly,
        category_id: anomaly[:category][:id],
        period_start_date: period.start_date,
        period_end_date: period.end_date,
        dismissed_at: nil
      )

      alert.assign_attributes(
        severity: anomaly[:severity],
        current_amount: anomaly[:current][:amount],
        average_amount: anomaly[:average][:amount],
        deviation_percent: anomaly[:deviation_percent],
        metadata: {
          "category_name" => anomaly[:category][:name],
          "category_color" => anomaly[:category][:color],
          "top_transactions" => anomaly[:top_transactions],
          "current_formatted" => anomaly[:current][:formatted],
          "average_formatted" => anomaly[:average][:formatted]
        }
      )

      if alert.new_record? || alert.changed?
        alert.save!
        alerts_created << alert
      end
    end

    # Create alerts for new merchants
    analysis[:new_merchants]&.each do |merchant_data|
      merchant_id = merchant_data[:merchant][:id].to_s

      # Skip if we already have an alert for this merchant in this period
      existing = where(
        family: family,
        alert_type: :new_merchant,
        period_start_date: period.start_date,
        period_end_date: period.end_date,
        dismissed_at: nil
      ).where("metadata->>'merchant_id' = ?", merchant_id).exists?

      next if existing

      alert = new(
        family: family,
        alert_type: :new_merchant,
        severity: :warning,
        period_start_date: period.start_date,
        period_end_date: period.end_date,
        current_amount: merchant_data[:total_spent][:amount],
        metadata: {
          "merchant_id" => merchant_id,
          "merchant_name" => merchant_data[:merchant][:name],
          "merchant_total_spent" => merchant_data[:total_spent][:formatted],
          "merchant_transaction_count" => merchant_data[:transaction_count],
          "first_transaction_date" => merchant_data[:first_transaction_date]
        }
      )

      alert.save!
      alerts_created << alert
    end

    alerts_created
  end
end
