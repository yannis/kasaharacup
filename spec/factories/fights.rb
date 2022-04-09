# frozen_string_literal: true

FactoryBot.define do
  factory :fight do
    association :individual_category
    number { |f|
      max_number = f.individual_category.fights.maximum(:number)
      (max_number.presence || 0) + 1
    }
    fighter_type { "Kenshi" }
    association :fighter_1, factory: :kenshi
    fighter_2 do |fight|
      build(:kenshi, cup: fight.fighter_1.cup)
    end
  end
end
