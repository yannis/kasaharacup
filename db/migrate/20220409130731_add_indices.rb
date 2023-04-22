# frozen_string_literal: true

class AddIndices < ActiveRecord::Migration[7.0]
  def change
    add_index :clubs, %i[name], unique: true
    add_index :cups, %i[start_on], unique: true
    add_index :individual_categories, %i[cup_id name], unique: true
    add_index :kenshis, %i[cup_id first_name last_name], unique: true
    add_index :products, %i[cup_id name_en], unique: true
    add_index :products, %i[cup_id name_fr], unique: true
    add_index :teams, %i[team_category_id name], unique: true
    add_index :team_categories, %i[cup_id name], unique: true
    add_index :fights, %i[individual_category_id number], unique: true

    change_column_null :users, :first_name, false
    change_column_null :users, :last_name, false
    change_column_null :clubs, :name, false
    change_column_null :cups, :start_on, false
    change_column_null :cups, :deadline, false
    change_column_null :cups, :junior_fees_chf, false
    change_column_null :cups, :junior_fees_eur, false
    change_column_null :cups, :adult_fees_chf, false
    change_column_null :cups, :adult_fees_eur, false
    change_column_null :events, :name_en, false
    change_column_null :events, :name_fr, false
    change_column_null :events, :start_on, false
    change_column_null :headlines, :title_fr, false
    change_column_null :headlines, :title_en, false
    change_column_null :headlines, :content_fr, false
    change_column_null :headlines, :content_en, false
    change_column_null :individual_categories, :name, false
    change_column_null :kenshis, :first_name, false
    change_column_null :kenshis, :last_name, false
    change_column_null :kenshis, :dob, false
    change_column_null :kenshis, :grade, false
    change_column_null :participations, :category_id, false
    change_column_null :participations, :kenshi_id, false
    change_column_null :products, :name_en, false
    change_column_null :products, :name_fr, false
    change_column_null :products, :fee_chf, false
    change_column_null :products, :fee_eu, false
    change_column_null :products, :cup_id, false
    change_column_null :purchases, :kenshi_id, false
    change_column_null :purchases, :product_id, false
    change_column_null :teams, :name, false
    change_column_null :teams, :team_category_id, false
    change_column_null :team_categories, :name, false
    change_column_null :team_categories, :cup_id, false
    change_column_null :fights, :individual_category_id, false
    change_column_null :fights, :fighter_1_id, false
    change_column_null :fights, :fighter_2_id, false
    change_column_null :fights, :number, false
  end
end
