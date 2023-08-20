# frozen_string_literal: true

class AddTimestampsToPersonalInfos < ActiveRecord::Migration[7.0]
  class PersonalInfo < ApplicationRecord
    belongs_to :kenshi
  end

  class Kenshi < ApplicationRecord
  end

  def change
    add_timestamps(:personal_infos, null: true)
    PersonalInfo.find_each do |personal_info|
      kenshi = personal_info.kenshi
      personal_info.update_columns(
        created_at: kenshi.created_at,
        updated_at: kenshi.created_at
      )
    end
  end
end
