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

  # Freezable's hooks (R15). bracket_only? has to come first and is not merely
  # the cheap half: dropping pool_size to 1 leaves the previous draw's pool
  # numbers on the teams, so team_pools alone would offer a freeze for a pool
  # phase that no longer exists. Same ordering as SeedsController#pool_cards?.
  # An existence check rather than #team_pools.any?: the cup panel's "N of M"
  # summary asks this once per category, and #team_pools loads every team to
  # build TeamPool objects nobody reads.
  def pools_freezable? = !bracket_only? && teams.where.not(pool_number: nil).exists?

  def bracket_freezable? = bracket_encounters.exists?

  # The tree's nodes, under the one name BracketSlotMove and
  # BracketWaitingEntries can ask either category kind for.
  def bracket_records = bracket_encounters

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
  # Memoized like #encounters_by_pool_number. Two paths confirm a lineup, and
  # neither can read a stale snapshot: EncounterLineupSeeder writes to the very
  # encounter it is seeding, which a suggestion always skips, so what it writes
  # could never appear here anyway; LineupsController#update writes and then
  # re-renders through respond_with_encounter, which builds its EncounterComponent
  # without auto_seed, so that render asks for no suggestion at all. Give that
  # responder auto_seed — or add any other write-then-suggest path on one category
  # instance — and the second side would be suggested from a pre-write snapshot.
  def lineup_set_encounters
    @lineup_set_encounters ||= encounters
      .where("lineup_1_set = TRUE OR lineup_2_set = TRUE")
      .includes(:team_fights)
      .order(updated_at: :desc, id: :desc)
      .to_a
  end

  # Both memos above hold rows read at first call. Plain ivars survive #reload,
  # which resets associations only, so clear them: a caller that reloads is
  # asking for the current state of the category, memos included.
  def reload(...)
    @encounters_by_pool_number = nil
    @lineup_set_encounters = nil
    super
  end

  def set_team_pools(random: Random.new)
    TeamPooler.new(self, random: random).set_pools
  end
end
