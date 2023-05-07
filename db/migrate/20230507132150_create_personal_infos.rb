# frozen_string_literal: true

class CreatePersonalInfos < ActiveRecord::Migration[7.0]
  def change
    create_enum :document_type, %w[passport id_card]
    create_table :personal_infos do |t|
      t.references :kenshi, null: false, foreign_key: true
      t.text :residential_address, null: true
      t.string :residential_zip_code, null: true
      t.string :residential_city, null: true
      t.string :residential_country, null: true
      t.string :residential_phone_number, null: true
      t.string :origin_country, null: true
      t.enum :document_type, enum_type: :document_type, null: true, default: nil
      t.string :document_number, null: true
    end
  end
end
