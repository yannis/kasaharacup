# frozen_string_literal: true

class AddReferences < ActiveRecord::Migration[7.0]
  def up
    add_foreign_key :events, :cups, column: :cup_id
    change_column :events, :cup_id, :integer, null: false, index: true
    add_foreign_key :headlines, :cups, column: :cup_id
    change_column :headlines, :cup_id, :integer, null: false, index: true
    add_foreign_key :individual_categories, :cups, column: :cup_id
    change_column :individual_categories, :cup_id, :integer, null: false, index: true
    add_foreign_key :kenshis, :cups, column: :cup_id
    change_column :kenshis, :cup_id, :integer, null: false, index: true
    add_foreign_key :kenshis, :users, column: :user_id
    change_column :kenshis, :user_id, :integer, null: false, index: true
    add_foreign_key :kenshis, :clubs, column: :club_id
    change_column :kenshis, :club_id, :integer, null: false, index: true
    add_foreign_key :participations, :teams, column: :team_id
    change_column :participations, :team_id, :integer, null: true, index: true
    add_foreign_key :participations, :kenshis, column: :kenshi_id
    change_column :participations, :kenshi_id, :integer, null: true, index: true
    add_foreign_key :products, :events, column: :event_id
    change_column :products, :event_id, :integer, null: true, index: true
    add_foreign_key :products, :cups, column: :cup_id
    change_column :products, :cup_id, :integer, null: true, index: true
    add_foreign_key :purchases, :kenshis, column: :kenshi_id
    change_column :purchases, :kenshi_id, :integer, null: true, index: true
    add_foreign_key :purchases, :products, column: :product_id
    change_column :purchases, :product_id, :integer, null: true, index: true
    add_foreign_key :team_categories, :cups, column: :cup_id
    change_column :team_categories, :cup_id, :integer, null: true, index: true
    add_foreign_key :teams, :team_categories, column: :team_category_id
    change_column :teams, :team_category_id, :integer, null: true, index: true
    add_foreign_key :users, :clubs, column: :club_id
    change_column :users, :club_id, :integer, null: true, index: true
  end

  def down
    change_column :users, :club_id, :integer, foreign_key: false, null: true
    remove_foreign_key :users, :clubs
    change_column :teams, :team_category_id, :integer, foreign_key: false, null: true
    remove_foreign_key :teams, :team_categories
    change_column :team_categories, :cup_id, :integer, foreign_key: false, null: true
    remove_foreign_key :team_categories, :cups
    change_column :purchases, :product_id, :integer, foreign_key: false, null: true
    remove_foreign_key :purchases, :products
    change_column :purchases, :kenshi_id, :integer, foreign_key: false, null: true
    remove_foreign_key :purchases, :kenshis
    change_column :products, :cup_id, :integer, foreign_key: false, null: true
    remove_foreign_key :products, :cups
    change_column :products, :event_id, :integer, foreign_key: false, null: true
    remove_foreign_key :products, :events
    change_column :participations, :kenshi_id, :integer, foreign_key: false, null: true
    remove_foreign_key :participations, :kenshis
    change_column :participations, :team_id, :integer, foreign_key: false, null: true
    remove_foreign_key :participations, :teams
    change_column :kenshis, :club_id, :integer, foreign_key: false, null: true
    remove_foreign_key :kenshis, :clubs
    change_column :kenshis, :user_id, :integer, foreign_key: false, null: true
    remove_foreign_key :kenshis, :users
    change_column :kenshis, :cup_id, :integer, foreign_key: false, null: true
    remove_foreign_key :kenshis, :cups
    change_column :individual_categories, :cup_id, :integer, foreign_key: false, null: true
    remove_foreign_key :individual_categories, :cups
    change_column :headlines, :cup_id, :integer, foreign_key: false, null: true
    remove_foreign_key :headlines, :cups
    change_column :events, :cup_id, :integer, foreign_key: false, null: true
    remove_foreign_key :events, :cups
  end
end
