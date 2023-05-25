# frozen_string_literal: true

class AddRequirePersonalInfosToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :require_personal_infos, :boolean, default: false, null: false
  end
end
