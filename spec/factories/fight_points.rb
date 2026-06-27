# frozen_string_literal: true

FactoryBot.define do
  factory :fight_point do
    association :scorable, factory: :fight
    fighter_side { "fighter_1" }
    kind { "men" }
  end
end
