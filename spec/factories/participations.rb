# frozen_string_literal: true

FactoryBot.define do
  factory :participation do
    association :category, factory: :individual_category
    kenshi { |p| build(:kenshi, cup: p.category.cup) }
  end
end
