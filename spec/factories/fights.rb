# frozen_string_literal: true

FactoryBot.define do
  factory :fight do
    individual_category
    number { |f|
      max_number = f.individual_category.fights.where(pool_number: nil).maximum(:number)
      (max_number.presence || 0) + 1
    }
    round { 1 }
    position { |f|
      max_position = f.individual_category.fights.where(round: f.round).maximum(:position)
      (max_position.presence || 0) + 1
    }
    fighter_type { "Kenshi" }
    fighter_1 do |fight|
      build(:kenshi, cup: fight.individual_category.cup,
        participations: [build(:participation, category: fight.individual_category)])
    end
    fighter_2 do |fight|
      build(:kenshi, cup: fight.individual_category.cup,
        participations: [build(:participation, category: fight.individual_category)])
    end

    trait :pool_fight do
      pool_number { 1 }
      round { nil }
      position { nil }
      number { |f|
        max_number = f.individual_category.fights.where(pool_number: f.pool_number).maximum(:number)
        (max_number.presence || 0) + 1
      }
    end

    trait :tiebreaker do
      pool_fight
      tiebreaker { true }
    end
  end
end
