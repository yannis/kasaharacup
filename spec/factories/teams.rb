# frozen_string_literal: true

FactoryBot.define do
  factory :team do
    name { "team_name_" + Faker::Company.name + rand(1000) }
  end
end
