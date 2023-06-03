# frozen_string_literal: true

FactoryBot.define do
  factory :kenshi do
    cup
    user
    club
    female { false }
    first_name { "#{Faker::Name.first_name}-#{Faker::Name.first_name} #{Faker::Name.middle_name}" }
    last_name { "#{Faker::Name.last_name} #{Faker::Name.last_name}" }
    dob { "1990-01-01" }
    grade { "kyu" }
  end
end
