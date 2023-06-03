# frozen_string_literal: true

FactoryBot.define do
  sequence(:seq) { |n| n }

  factory :product do
    cup
    name_en { "#{Faker::Adjective.positive} #{Faker::Ancient.primordial} #{generate(:seq)}" }
    name_fr { "#{Faker::Adjective.positive} #{Faker::Ancient.primordial} #{generate(:seq)}" }
    fee_chf { 10 }
    fee_eu { 8 }
  end
end
