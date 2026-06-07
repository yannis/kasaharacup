# frozen_string_literal: true

class Encounter < ApplicationRecord
  belongs_to :team_category
  belongs_to :team_1, class_name: "Team"
  belongs_to :team_2, class_name: "Team"
  belongs_to :winner, class_name: "Team", optional: true
  has_many :team_fights, -> { order(:position) }, dependent: :destroy

  validate :teams_differ
  validate :teams_in_category

  delegate :team_size, to: :team_category

  def result
    EncounterResult.new(self)
  end

  # Persist the derived winning team; no-op when already current. Called
  # post-commit (from TeamFight), so its own write never lands mid-transaction.
  def recompute_winner!
    derived = result.winner
    return if winner_id == derived&.id

    update!(winner: derived)
  end

  private def teams_differ
    errors.add(:team_2, "must differ from team 1") if team_1_id && team_1_id == team_2_id
  end

  private def teams_in_category
    [team_1, team_2].compact.each do |team|
      next if team.team_category_id == team_category_id

      errors.add(:base, "#{team.name} is not in this category")
    end
  end
end
