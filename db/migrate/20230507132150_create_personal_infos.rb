# frozen_string_literal: true

class CreatePersonalInfos < ActiveRecord::Migration[7.0]
  def change
    create_enum :document_type, %w[passport id_card]
    create_table :personal_infos do |t|
      t.references :kenshi, null: false, foreign_key: true
      t.text :residential_address, null: false
      t.string :residential_zip_code, null: false
      t.string :residential_city, null: false
      t.string :residential_country, null: false
      t.string :residential_phone_number, null: false
      t.string :origin_country, null: false
      t.enum :document_type, enum_type: :document_type, null: false, default: nil
      t.string :document_number, null: false
    end
  end
end
