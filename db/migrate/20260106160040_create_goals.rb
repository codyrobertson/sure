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

      t.timestamps
    end

    add_index :goals, :family_id
    add_index :goals, :account_id
    add_index :goals, [:family_id, :account_id], name: "index_goals_on_family_and_account"
  end
end
