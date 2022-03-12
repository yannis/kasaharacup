# frozen_string_literal: true

FactoryBot.define do
  factory :video do
    url { Faker::Internet.url }
    name { Faker::Lorem.sentence }
    association :category, factory: :individual_category
  end
end
