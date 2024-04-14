# frozen_string_literal: true

FactoryBot.define do
  factory :personal_info do
    kenshi
    residential_phone_number { Faker::PhoneNumber.phone_number }
    residential_address { Faker::Address.street_address }
    residential_city { Faker::Address.city }
    residential_zip_code { Faker::Address.zip_code }
    residential_country { ISO3166::Country.all.map(&:alpha2).sample }
    origin_country { ISO3166::Country.all.map(&:alpha2).sample }
    document_type { %w[passport id_card].sample }
    document_number { Faker::IdNumber.valid }
    email { Faker::Internet.email }
  end
end
