# frozen_string_literal: true

class AddGenderRestrictionToTeamCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :team_categories, :gender_restriction, :enum, enum_type: :gender_restriction
  end
end
