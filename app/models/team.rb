# frozen_string_literal: true

class Team < ApplicationRecord
  include ActsAsFighter
  include Seedable
  include FreezablePoolMember

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
  #
  # The fragment names the teams table literally, so it is only correct where
  # teams is unaliased. Merged into a query that joins teams twice -- any
  # self-join, such as Encounter.joins(:team_1, :team_2) -- it binds to
  # whichever copy kept the bare name, silently and without error.
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

  # FreezablePoolMember hooks. team_category_id is permitted by
  # app/admin/team.rb, so reassigning a pooled team is a formation change that
  # the pool attributes never see.
  private def freeze_category = team_category

  private def freeze_category_moving? = will_save_change_to_team_category_id?

  # Guarded on the previous id: on a create it is nil, and find_by(id: nil)
  # still costs a WHERE id IS NULL round trip on every pooled row the pooler
  # writes. Participation needs no equivalent — its category_type_was is nil
  # there, so the case below falls through without querying.
  private def freeze_category_left
    TeamCategory.find_by(id: team_category_id_was) if team_category_id_was
  end

  # Seedable hooks: a team category owns the seed order its teams share.
  def seed_group = team_category

  def seed_siblings = team_category.teams

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
