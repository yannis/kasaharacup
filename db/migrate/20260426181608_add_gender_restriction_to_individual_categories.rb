# frozen_string_literal: true

class AddGenderRestrictionToIndividualCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :individual_categories, :gender_restriction, :string
  end
end
