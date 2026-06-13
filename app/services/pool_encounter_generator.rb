# frozen_string_literal: true

# Creates a team category's pool round-robin encounters (sibling of
# PoolFightGenerator). Pairs come from Pools::CyclicPairing (cyclic order, same
# as the individual side). Idempotent: skips pools that already have encounters.
class PoolEncounterGenerator
  def initialize(team_category, pool_number: nil)
    @team_category = team_category
    @pool_number = pool_number
  end

  def call
    team_category.transaction do
      pools_to_generate.each { |pool| generate_for(pool) }
    end
  end

  private attr_reader :team_category, :pool_number

  def pools_to_generate
    candidates = team_category.team_pools
    candidates = candidates.select { |pool| pool.number == pool_number } if pool_number
    candidates.reject { |pool| team_category.encounters.exists?(pool_number: pool.number) }
  end

  def generate_for(pool)
    teams = pool.teams
    Pools::CyclicPairing.pairs_for(teams.size).each do |low, high|
      team_1 = teams[low - 1]
      team_2 = teams[high - 1]
      next if team_1.blank? || team_2.blank?

      team_category.encounters.create!(pool_number: pool.number, team_1: team_1, team_2: team_2)
    end
  end
end
