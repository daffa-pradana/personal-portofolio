class CreateKnowledgeEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :knowledge_entries do |t|
      t.string :category, null: false
      t.string :title, null: false
      t.text :content, null: false
      t.integer :position

      t.timestamps
    end

    # KnowledgeRetriever queries by category and orders by position — see
    # app/services/knowledge_retriever.rb.
    add_index :knowledge_entries, :category
    add_index :knowledge_entries, :position
  end
end
