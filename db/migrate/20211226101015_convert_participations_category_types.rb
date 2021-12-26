# frozen_string_literal: true

class ConvertParticipationsCategoryTypes < ActiveRecord::Migration[7.0]
  def up
    Participation.find_each do |participation|
      category_type = participation.category_type.split("::").last
      next unless category_type

      participation.category_type = category_type
      participation.save(validate: false)
    end
  end

  def down
    Participation.find_each do |participation|
      participation.update!(category_type: "#{participation.category_type}")
    end
  end
end
