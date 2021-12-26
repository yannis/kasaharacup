# frozen_string_literal: true

FactoryBot.define do
  factory :fight do
    association :individual_category
    number { |f|
      max_number = f.individual_category.fights.maximum(:number)
      (max_number.presence || 0) + 1
    }
    fighter_type { "Kenshi" }
    fighter_1_id { create(:kenshi).id }
    fighter_2_id { create(:kenshi).id }
  end
end
