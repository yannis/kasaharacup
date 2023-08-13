# frozen_string_literal: true

class AddEmailToPersonalInfos < ActiveRecord::Migration[7.0]
  class PersonalInfo < ApplicationRecord
    belongs_to :kenshi

    encrypts :email
  end

  class Kenshi < ApplicationRecord
    belongs_to :user
  end

  class User < ApplicationRecord
  end

  def change
    add_column :personal_infos, :email, :string, null: true, index: true

    PersonalInfo.find_each do |personal_info|
      personal_info.update!(email: personal_info.kenshi.user.email)
    end

    change_column_null :personal_infos, :email, false
  end
end
