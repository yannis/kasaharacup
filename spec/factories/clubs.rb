# frozen_string_literal: true

FactoryBot.define do
  factory :club do
    name { Faker::Company.name }
  end
end
