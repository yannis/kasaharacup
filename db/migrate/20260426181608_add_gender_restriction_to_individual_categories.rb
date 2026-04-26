# frozen_string_literal: true

class AddGenderRestrictionToIndividualCategories < ActiveRecord::Migration[8.1]
  def change
    create_enum :gender_restriction, %w[female male]
    add_column :individual_categories, :gender_restriction, :enum, enum_type: :gender_restriction
  end
end
