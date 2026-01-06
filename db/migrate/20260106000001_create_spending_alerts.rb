class CreateSpendingAlerts < ActiveRecord::Migration[7.2]
  def change
    create_table :spending_alerts, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.references :category, foreign_key: true, type: :uuid

      t.string :alert_type, null: false  # 'category_anomaly', 'new_merchant'
      t.string :severity, null: false    # 'warning', 'alert'

      t.decimal :current_amount, precision: 19, scale: 4
      t.decimal :average_amount, precision: 19, scale: 4
      t.decimal :deviation_percent, precision: 5, scale: 1

      t.jsonb :metadata, default: {}  # store top_transactions, merchant info, etc.

      t.datetime :dismissed_at
      t.date :period_start_date, null: false
      t.date :period_end_date, null: false

      t.timestamps
    end

    add_index :spending_alerts, [:family_id, :dismissed_at, :created_at], name: "index_spending_alerts_active"
    add_index :spending_alerts, [:family_id, :alert_type, :category_id, :period_start_date],
              unique: true,
              where: "dismissed_at IS NULL",
              name: "index_spending_alerts_uniqueness"
    # Index for dashboard query: active alerts for a period, ordered by created_at
    add_index :spending_alerts,
              [:family_id, :period_start_date, :period_end_date, :created_at],
              where: "dismissed_at IS NULL",
              name: "index_spending_alerts_dashboard"
  end
end
