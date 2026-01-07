class CreateBudgetAlerts < ActiveRecord::Migration[7.2]
  def change
    create_table :budget_alerts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.references :budget, null: false, foreign_key: true, type: :uuid
      t.references :budget_category, foreign_key: true, type: :uuid

      t.string :alert_type, null: false # 'threshold_50', 'threshold_80', 'threshold_100', 'overspent'
      t.string :severity, null: false   # 'info', 'warning', 'critical'

      t.decimal :current_amount, precision: 19, scale: 4
      t.decimal :budgeted_amount, precision: 19, scale: 4
      t.decimal :spent_percent, precision: 5, scale: 1

      t.jsonb :metadata, default: {}

      t.datetime :dismissed_at
      t.date :period_start_date, null: false
      t.date :period_end_date, null: false

      t.timestamps
    end

    add_index :budget_alerts, [:family_id, :budget_id, :alert_type, :budget_category_id],
              name: "idx_budget_alerts_unique_active",
              unique: true,
              where: "dismissed_at IS NULL AND budget_category_id IS NOT NULL"

    add_index :budget_alerts, [:family_id, :budget_id, :alert_type],
              name: "idx_budget_alerts_unique_active_overall",
              unique: true,
              where: "dismissed_at IS NULL AND budget_category_id IS NULL"

    add_index :budget_alerts, :alert_type
    add_index :budget_alerts, :severity
    add_index :budget_alerts, :dismissed_at
  end
end
