class DetectBudgetAlertsJob < ApplicationJob
  queue_as :scheduled

  def perform(family_id = nil)
    families = family_id ? Family.where(id: family_id) : Family.all

    families.find_each do |family|
      detect_alerts_for_family(family)
    rescue StandardError => e
      Rails.logger.error("Failed to detect budget alerts for family #{family.id}: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
    end
  end

  private

  def detect_alerts_for_family(family)
    # Get current month's budget
    budget = Budget.find_or_bootstrap(family, start_date: Date.current)
    return unless budget&.initialized?

    # Use the detector to find and create alerts
    detector = BudgetAlertDetector.new(budget)
    alerts_created = detector.detect_and_create_alerts

    if alerts_created.any?
      Rails.logger.info("Created #{alerts_created.count} budget alerts for family #{family.id}")
    end
  end
end
