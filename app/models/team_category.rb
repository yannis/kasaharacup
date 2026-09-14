# frozen_string_literal: true

class TeamCategory < ApplicationRecord
  include ActsAsCategory

  belongs_to :cup, inverse_of: :team_categories
  has_many :teams, inverse_of: :team_category, dependent: :destroy
  has_many :participations, as: :category, dependent: :destroy
  has_many :videos, as: :category, dependent: :destroy
  has_many :documents, as: :category, dependent: :destroy
  has_many :kenshis, through: :teams
  has_many :encounters, dependent: :destroy
  # Bracket encounters are the elimination-tree nodes: no pool_number AND a round.
  # The round guard excludes ad-hoc encounters created via the manual "new
  # encounter" form (pool_number nil, round nil), which otherwise pollute the
  # bracket and break the tree layout / builder idempotency.
  has_many :bracket_encounters, -> { where(pool_number: nil).where.not(round: nil) },
    class_name: "Encounter", inverse_of: :team_category

  validates :team_size, inclusion: {in: [3, 5]}

  delegate :year, to: :cup

  def full_name
    "#{name} (#{cup.year})"
  end

  # No pool phase: teams go straight into the elimination bracket. The <= 1
  # threshold matches TeamPooler, which clears pools for these categories.
  def bracket_only?
    pool_size.to_i <= 1
  end

  # NOT memoized: regeneration paths (TeamPoolMove -> PoolEncounterGenerator)
  # reuse one category instance and re-read this after mutating pool membership,
  # so a cached snapshot would regenerate pools from stale membership. Callers
  # that read it repeatedly within a single render pass it down as a local.
  def team_pools
    teams.where.not(pool_number: nil).group_by(&:pool_number).sort.map do |number, pool_teams|
      TeamPool.new(number: number, teams: pool_teams)
    end
  end

  def encounters_by_pool_number
    @encounters_by_pool_number ||= encounters.where.not(pool_number: nil)
      .includes(:winner, team_1: :kenshis, team_2: :kenshis,
        team_fights: [:fight_points, :kenshi_1, :kenshi_2, :winner])
      .group_by(&:pool_number)
  end

  # The category's encounters that carry a confirmed lineup, newest first, with
  # their bouts — the raw material EncounterLineupSuggestion reads a team's last
  # fighter order from. Loaded once per instance: the pool page suggests an
  # order for both sides of every pool encounter, and asking per side turned
  # that into two queries per encounter.
  #
  # Memoized like #encounters_by_pool_number, and safe for the same reason: only
  # read paths ask for a suggestion. The one writer, EncounterLineupSeeder,
  # confirms a lineup on the encounter it is seeding, and a suggestion always
  # skips its own encounter — so what it writes could never have been read here.
  def lineup_set_encounters
    @lineup_set_encounters ||= encounters
      .where("lineup_1_set = TRUE OR lineup_2_set = TRUE")
      .includes(:team_fights)
      .order(updated_at: :desc, id: :desc)
      .to_a
  end

  def set_team_pools(random: Random.new)
    TeamPooler.new(self, random: random).set_pools
  end
end
