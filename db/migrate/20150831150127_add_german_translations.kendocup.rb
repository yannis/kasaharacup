# This migration comes from kendocup (originally 20150815155232)
class AddGermanTranslations < ActiveRecord::Migration
  def change
    add_column :events, :name_de, :string
    add_column :headlines, :title_de, :string
    add_column :headlines, :content_de, :text
    add_column :individual_categories, :description_de, :text
    add_column :products, :name_de, :string
    add_column :products, :description_de, :text
    add_column :team_categories, :description_de, :text
  end
end
