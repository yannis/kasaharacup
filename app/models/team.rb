# frozen_string_literal: true

class Team < ApplicationRecord
  include ActsAsFighter

  belongs_to :team_category, inverse_of: :teams
  has_many :participations, dependent: :destroy
  has_many :kenshis, through: :participations

  validates :name, presence: true
  validates :name, uniqueness: {scope: :team_category_id}

  delegate :cup, to: :team_category
  # allow_nil so the predicates below stay total for a Team built before its
  # category is assigned. The column is NOT NULL with a foreign key, so this
  # only concerns unsaved records.
  delegate :team_size, to: :team_category, allow_nil: true

  def self.empty
    where.missing(:participations)
  end

  # A team is nothing but its members — until the competition starts to refer
  # to it. A pool, a bracket slot, a seeding, a podium place all outlive the
  # roster (the participations behind a 2018 winner are long gone), and the
  # encounter foreign keys nullify rather than block, so destroying a drawn
  # team would silently blank a bracket slot instead of failing loudly. Only
  # an empty team nothing points at is a leftover of registration.
  NOT_DRAWN = <<~SQL.squish
    NOT EXISTS (
      SELECT 1 FROM encounters
      WHERE encounters.team_1_id = teams.id
        OR encounters.team_2_id = teams.id
        OR encounters.winner_id = teams.id
    )
  SQL
  private_constant :NOT_DRAWN

  def self.abandoned
    empty.where(rank: nil, pool_number: nil, seed: nil).where(NOT_DRAWN)
  end

  # Both sides of the comparison are correlated subqueries rather than joins.
  # Joining team_categories would be redundant at best: the usual entry point
  # is Cup#teams, a has_many :through that already joins that table, so Rails
  # aliases the second join to team_categories_teams. Both copies key on
  # teams.team_category_id and therefore read the same row, but the scopes
  # should not have to rely on that. Counting in a subquery instead of
  # GROUP BY ... HAVING also keeps the result an ordinary relation, so callers
  # can order, chain and #count it like any other scope, and a team with no
  # members at all still counts as incomplete.
  #
  # The fragments name the teams table literally, so these scopes are only
  # correct where teams is unaliased. Merged into a query that joins teams
  # twice -- Encounter.joins(:team_1, :team_2), or any self-join -- they bind
  # to whichever copy kept the bare name, silently and without error.
  MEMBER_COUNT_SQL = "(SELECT COUNT(*) FROM participations WHERE participations.team_id = teams.id)"
  TEAM_SIZE_SQL = "(SELECT team_size FROM team_categories WHERE team_categories.id = teams.team_category_id)"
  COMPLETE_SQL = "#{MEMBER_COUNT_SQL} >= #{TEAM_SIZE_SQL}"
  private_constant :MEMBER_COUNT_SQL, :TEAM_SIZE_SQL, :COMPLETE_SQL

  def self.complete
    where(COMPLETE_SQL)
  end

  # The complement of .complete by construction, so the two cannot drift apart.
  def self.incomplete
    where.not(COMPLETE_SQL)
  end

  def to_s
    name
  end

  def complete?
    team_size.present? && participations.size >= team_size
  end

  def incomplete?
    !complete?
  end

  # A team stays in the running while it can still take a majority of the
  # bouts: 3 of 5, 2 of 3. The missing fighters are forfeited.
  def isvalid?
    team_size.present? && participations.size > team_size / 2
  end

  def name_and_status
    name_and_status = [name]
    name_and_status << "(complete)" if complete?
    name_and_status.join(" ")
  end

  def name_and_category
    "#{name} (#{team_category.name})"
  end

  def category_and_name
    "#{team_category.name} (#{name})"
  end

  def poster_name
    name.to_s.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/, "").upcase
  end

  def fitness
    kenshis.inject(0) { |sum, k| sum + k.fitness }
  end
end
