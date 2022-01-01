# frozen_string_literal: true

FactoryBot.define do
  sequence(:integer) { |n| n }

  factory :event do
    association :cup
    name_en { "#{Faker::Adjective.positive} #{Faker::Tea.variety}" }
    name_fr { "#{Faker::Adjective.positive} #{Faker::Tea.variety}" }
    start_on { |e| e.cup.start_on.to_time + generate(:integer).hours }
  end
end
