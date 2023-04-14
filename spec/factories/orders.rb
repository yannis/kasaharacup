# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    user
    cup
  end

  trait :with_purchases do
    after(:create) do
      create_list(:purchase, 2)
    end
  end

  trait :paid do
    after(:build) do |order|
      order.pay!
    end
  end
end
