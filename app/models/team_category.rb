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

  validates :team_size, inclusion: {in: [3, 5]}

  delegate :year, to: :cup

  def full_name
    "#{name} (#{cup.year})"
  end

  def team_pools
    teams.where.not(pool_number: nil).group_by(&:pool_number).sort.map do |number, pool_teams|
      TeamPool.new(number: number, teams: pool_teams)
    end
  end

  def encounters_by_pool_number
    @encounters_by_pool_number ||= encounters.where.not(pool_number: nil)
      .includes(team_fights: :fight_points)
      .group_by(&:pool_number)
  end

  def set_team_pools(random: Random.new)
    TeamPooler.new(self, random: random).set_pools
  end
end
