class CreateLangugeBits < ActiveRecord::Migration
  def change
    create_table :adjectives do |t|
      t.column :segment, :text
      t.column :category, :string, default: "corporate"
    end
    create_table :connectors do |t|
      t.column :segment, :string
      t.column :category, :string, default: "corporate"
    end
    create_table :nouns do |t|
      t.column :segment, :string
      t.column :category, :string, default: "corporate"
    end
    create_table :verbs do |t|
      t.column :category, :string, default: "corporate"
      t.column :segment, :string
    end
    create_table :prefixes do |t|
      t.column :category, :string, default: "corporate"
      t.column :segment, :text
    end
    create_table :lexicons do |t|
      t.column :category, :string, default: "corporate"
      t.column :sentence, :text
    end
  end
end
