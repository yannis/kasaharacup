# frozen_string_literal: true

FactoryBot.define do
  factory :purchase do
    association :product
    association :kenshi
  end
end
