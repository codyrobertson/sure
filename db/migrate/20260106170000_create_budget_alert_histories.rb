class CreateBudgetAlertHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :budget_alert_histories, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :budget, null: false, foreign_key: true, type: :uuid
      t.references :budget_category, null: false, foreign_key: true, type: :uuid
      t.string :alert_type, null: false # 'exceeded' or 'warning'
      t.decimal :budgeted_amount, precision: 19, scale: 4
      t.decimal :actual_amount, precision: 19, scale: 4
      t.integer :percent_spent
      t.string :currency, limit: 3

      t.timestamps
    end

    add_index :budget_alert_histories, [:user_id, :budget_id, :budget_category_id, :alert_type],
              name: "idx_budget_alert_histories_unique_alert",
              unique: true
    add_index :budget_alert_histories, [:user_id, :created_at]
    add_index :budget_alert_histories, :alert_type
  end
end
