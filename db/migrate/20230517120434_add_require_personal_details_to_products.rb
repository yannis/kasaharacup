# frozen_string_literal: true

class AddRequirePersonalDetailsToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :require_personal_details, :boolean, default: false, null: false
  end
end
