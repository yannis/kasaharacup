# frozen_string_literal: true

FactoryBot.define do
  factory :kenshi do
    association :cup, start_on: "#{Date.current.year}-11-30"
    user
    club
    female { false }
    first_name { "#{Faker::Name.first_name}-#{Faker::Name.first_name} #{Faker::Name.middle_name}" }
    last_name { "#{Faker::Name.last_name} #{Faker::Name.last_name}" }
    dob { "1990-01-01" }
    grade { "kyu" }
  end
end
