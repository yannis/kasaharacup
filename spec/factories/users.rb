# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { "#{Faker::Name.first_name} #{Faker::Name.middle_name}" }
    last_name { "#{Faker::Name.last_name} #{Faker::Name.last_name}" }
    email { Faker::Internet.unique.email }
    password { Faker::Internet.password }
    club

    trait :admin do
      admin { true }
    end
  end
end
