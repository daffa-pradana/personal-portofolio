class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :title, null: false
      t.text :description
      t.string :tags, array: true, default: []
      t.string :source_code_url
      t.string :live_url
      t.integer :position

      t.timestamps
    end
  end
end
