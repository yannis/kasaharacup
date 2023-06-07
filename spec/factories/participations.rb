# frozen_string_literal: true

FactoryBot.define do
  factory :participation do
    category factory: %i[individual_category]
    kenshi { |p| build(:kenshi, cup: p.category.cup) }
  end
end
