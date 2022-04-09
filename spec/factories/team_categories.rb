# frozen_string_literal: true

FactoryBot.define do
  factory :team_category do
    association :cup
    name { "#{Faker::Adjective.positive} #{Faker::Adjective.positive} #{Faker::Ancient.primordial}" }
  end
end
