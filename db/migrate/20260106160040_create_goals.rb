class CreateGoals < ActiveRecord::Migration[7.2]
  def change
    create_table :goals, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, type: :uuid

      t.string :name, null: false
      t.text :description

      t.decimal :target_amount, precision: 19, scale: 4, null: false
      t.decimal :starting_balance, precision: 19, scale: 4
      t.string :currency, null: false

      t.date :target_date
      t.string :status, default: "active", null: false

      t.timestamps
    end

    # Note: t.references already creates indexes on family_id and account_id
    add_index :goals, :status
    add_index :goals, [:family_id, :status], name: "index_goals_on_family_and_status"
  end
end
