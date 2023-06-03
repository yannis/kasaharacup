# frozen_string_literal: true

FactoryBot.define do
  factory :purchase do
    product
    kenshi { association :kenshi, cup: product.cup }
  end
end
