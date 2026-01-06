class BudgetAlert < ApplicationRecord
  # Threshold percentages for budget alerts
  THRESHOLDS = {
    threshold_50: 50,
    threshold_80: 80,
    threshold_100: 100
  }.freeze

  belongs_to :family
  belongs_to :budget
  belongs_to :budget_category, optional: true

  enum :alert_type, {
    threshold_50: "threshold_50",
    threshold_80: "threshold_80",
    threshold_100: "threshold_100",
    overspent: "overspent"
  }, prefix: true

  enum :severity, {
    info: "info",
    warning: "warning",
    critical: "critical"
  }, prefix: true

  validates :alert_type, :severity, :period_start_date, :period_end_date, presence: true

  scope :active, -> { where(dismissed_at: nil) }
  scope :dismissed, -> { where.not(dismissed_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_severity, ->(sev) { where(severity: sev) }
  scope :for_period, ->(period) { where(period_start_date: period.start_date, period_end_date: period.end_date) }
  scope :for_budget, ->(budget) { where(budget: budget) }
  scope :overall_budget, -> { where(budget_category_id: nil) }
  scope :category_specific, -> { where.not(budget_category_id: nil) }

  def active?
    dismissed_at.nil?
  end

  def dismissed?
    dismissed_at.present?
  end

  def dismiss!
    update!(dismissed_at: Time.current)
  end

  def category_name
    budget_category&.category&.name || metadata&.dig("category_name")
  end

  def threshold_percent
    THRESHOLDS[alert_type.to_sym] || spent_percent
  end

  def overall_budget_alert?
    budget_category_id.nil?
  end

  def category_alert?
    budget_category_id.present?
  end

  class << self
    def severity_for_threshold(percent)
      if percent >= 100
        :critical
      elsif percent >= 80
        :warning
      else
        :info
      end
    end

    def alert_type_for_percent(percent)
      if percent > 100
        :overspent
      elsif percent >= 100
        :threshold_100
      elsif percent >= 80
        :threshold_80
      elsif percent >= 50
        :threshold_50
      end
    end
  end
end
