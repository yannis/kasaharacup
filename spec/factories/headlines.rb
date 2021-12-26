# frozen_string_literal: true

FactoryBot.define do
  factory :headline do
    association :cup, factory: :cup, start_on: "#{Date.current.year}-11-30"
    title_fr { Faker::Lorem.sentence }
    title_en { Faker::Lorem.sentence }
    content_fr { Faker::Lorem.paragraphs(number: 2) }
    content_en { Faker::Lorem.paragraphs(number: 2) }
  end
end
