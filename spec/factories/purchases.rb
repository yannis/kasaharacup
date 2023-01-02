# frozen_string_literal: true

FactoryBot.define do
  factory :purchase do
    product
    kenshi { |p| association :kenshi, cup: p.product.cup }
    order { |p| association :order, cup: p.product.cup }
  end
end
