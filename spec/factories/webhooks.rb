# frozen_string_literal: true

FactoryBot.define do
  factory :webhook do
    event { "MyText" }
    payload { "MyText" }
  end
end
