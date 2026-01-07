class BudgetAlertHistory < ApplicationRecord
  belongs_to :user
  belongs_to :budget
  belongs_to :budget_category

  ALERT_TYPES = %w[exceeded warning].freeze

  validates :alert_type, presence: true, inclusion: { in: ALERT_TYPES }
  validates :user_id, uniqueness: {
    scope: [:budget_id, :budget_category_id, :alert_type],
    message: "has already received this alert for this budget category"
  }

  scope :exceeded, -> { where(alert_type: "exceeded") }
  scope :warning, -> { where(alert_type: "warning") }
  scope :for_budget, ->(budget) { where(budget: budget) }
  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { where("created_at > ?", 30.days.ago) }

  # Check if an alert has already been sent for this combination
  def self.already_sent?(user:, budget:, budget_category:, alert_type:)
    exists?(
      user: user,
      budget: budget,
      budget_category: budget_category,
      alert_type: alert_type
    )
  end

  # Record a sent alert
  def self.record_alert!(user:, budget:, budget_category:, alert_type:)
    create!(
      user: user,
      budget: budget,
      budget_category: budget_category,
      alert_type: alert_type,
      budgeted_amount: budget_category.budgeted_spending,
      actual_amount: budget_category.actual_spending,
      percent_spent: budget_category.percent_of_budget_spent,
      currency: budget_category.currency
    )
  rescue ActiveRecord::RecordNotUnique
    # Alert already exists, return the existing record
    find_by(
      user: user,
      budget: budget,
      budget_category: budget_category,
      alert_type: alert_type
    )
  end

  # Clean up old alert history (keep only current month's data)
  def self.cleanup_old_records!(keep_budget_ids: [])
    where.not(budget_id: keep_budget_ids).delete_all
  end
end
