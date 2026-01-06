class Goal < ApplicationRecord
  include Monetizable

  belongs_to :family
  belongs_to :account

  validates :name, presence: true
  validates :target_amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true

  monetize :target_amount, :starting_balance, :current_balance, :remaining_amount

  enum :status, {
    active: "active",
    completed: "completed",
    paused: "paused",
    cancelled: "cancelled"
  }, validate: true

  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }
  scope :paused, -> { where(status: "paused") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :in_progress, -> { where(status: %w[active paused]) }
  scope :by_target_date, -> { order(target_date: :asc) }
  scope :recent, -> { order(created_at: :desc) }

  def current_balance
    account.balance
  end

  def remaining_amount
    [target_amount - current_balance, 0].max
  end

  def progress_percentage
    return 0 if target_amount.zero?
    return 100 if current_balance >= target_amount

    (current_balance / target_amount * 100).round(2)
  end

  def on_track?
    return true if target_date.nil?
    return true if current_balance >= target_amount

    days_remaining = (target_date - Date.current).to_i
    return false if days_remaining <= 0

    required_daily_savings = remaining_amount / days_remaining
    actual_daily_rate = daily_savings_rate

    actual_daily_rate >= required_daily_savings
  end

  def days_until_target
    return nil if target_date.nil?

    (target_date - Date.current).to_i
  end

  def complete!
    update!(status: "completed")
  end

  private

  def daily_savings_rate
    return 0 if created_at.nil?

    days_since_start = (Date.current - created_at.to_date).to_i
    return 0 if days_since_start <= 0

    progress_amount = current_balance - (starting_balance || 0)
    progress_amount / days_since_start
  end
end
