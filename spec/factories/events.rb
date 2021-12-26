# frozen_string_literal: true

FactoryBot.define do
  sequence(:integer) { |n| n }

  factory :event do
    association :cup
    name_en { Faker::Name.unique.last_name }
    name_fr { Faker::Name.unique.last_name }
    name_de { Faker::Name.unique.last_name }
    start_on { |e| e.cup.start_on.to_time + generate(:integer).hours }
  end
end
