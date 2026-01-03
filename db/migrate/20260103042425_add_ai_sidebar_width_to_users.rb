class AddAiSidebarWidthToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :ai_sidebar_width, :integer
  end
end
