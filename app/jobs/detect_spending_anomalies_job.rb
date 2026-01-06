class DetectSpendingAnomaliesJob < ApplicationJob
  queue_as :scheduled

  def perform(family_id = nil)
    families = family_id ? Family.where(id: family_id) : Family.all

    families.find_each do |family|
      detect_anomalies_for_family(family)
    rescue StandardError => e
      Rails.logger.error("Failed to detect spending anomalies for family #{family.id}: #{e.message}")
    end
  end

  private

  def detect_anomalies_for_family(family)
    # Skip families without transaction history
    return unless family.transactions.any?

    # Use current month as the period
    period = Period.current

    # Use the existing AnomalyDetector
    detector = Insights::AnomalyDetector.new(family, period: period)
    analysis = detector.analyze

    # Only create alerts if there are anomalies or new merchants
    return if analysis[:anomalies].blank? && analysis[:new_merchants].blank?

    # Create alerts from the analysis
    alerts_created = SpendingAlert.create_from_anomaly_analysis(family, period, analysis)

    Rails.logger.info("Created #{alerts_created.count} spending alerts for family #{family.id}")
  end
end
