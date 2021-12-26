# frozen_string_literal: true

FactoryBot.define do
  factory :product do
    cup
    name_en { "#{Faker::Adjective.positive} #{Faker::Ancient.primordial}" }
    name_fr { "#{Faker::Adjective.positive} #{Faker::Ancient.primordial}" }
    name_de { "#{Faker::Adjective.positive} #{Faker::Ancient.primordial}" }
    fee_chf { 10 }
    fee_eu { 8 }
  end
end
