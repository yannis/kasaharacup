# frozen_string_literal: true

FactoryBot.define do
  factory :team_fight do
    encounter
    position do |tf|
      (tf.encounter.team_fights.maximum(:position) || 0) + 1
    end
  end
end
