class AddSearchVectorToEntries < ActiveRecord::Migration[7.2]
  def change
    # Add generated tsvector column combining name and notes for full-text search
    add_column :entries, :search_vector, :virtual, type: :tsvector,
      as: "to_tsvector('simple', coalesce(name, '')) || to_tsvector('simple', coalesce(notes, ''))",
      stored: true

    # Add GIN index for fast full-text search
    add_index :entries, :search_vector, using: :gin
  end
end
