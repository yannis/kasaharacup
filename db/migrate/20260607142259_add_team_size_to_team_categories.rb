# frozen_string_literal: true

class AddTeamSizeToTeamCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :team_categories, :team_size, :integer, default: 5, null: false
  end
end
