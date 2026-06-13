# frozen_string_literal: true

FactoryBot.define do
  factory :encounter do
    team_category
    team_1 { association :team, team_category: team_category }
    team_2 { association :team, team_category: team_category }
  end
end
