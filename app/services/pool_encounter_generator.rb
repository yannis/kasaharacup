# frozen_string_literal: true

# Creates a team category's pool encounters (sibling of PoolFightGenerator).
# Pairs come from Pools::CyclicPairing — a single cycle (each team meets its two
# cycle-neighbours), NOT a full round-robin, matching the individual side —
# created in the order and on the sides Pools::TeamFightOrder fights them:
# team_1 is white, team_2 red.
# Idempotent: skips pools that already have encounters.
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

  private def pools_to_generate
    generated = team_category.encounters.distinct.pluck(:pool_number)
    candidates = team_category.team_pools
    candidates = candidates.select { |pool| pool.number == pool_number } if pool_number
    candidates.reject { |pool| generated.include?(pool.number) }
  end

  private def generate_for(pool)
    teams = pool.teams
    Pools::TeamFightOrder.sides_for(teams.size).each do |white, red|
      team_1 = teams[white - 1]
      team_2 = teams[red - 1]
      next if team_1.blank? || team_2.blank?

      team_category.encounters.create!(pool_number: pool.number, team_1: team_1, team_2: team_2)
    end
  end
end
