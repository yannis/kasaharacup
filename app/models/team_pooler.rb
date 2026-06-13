# frozen_string_literal: true

# Distributes a team category's teams into pools (sibling of SmartPooler).
# The seed-marked teams (medalists) go into distinct pools first; the rest are
# drawn at random into the remaining open slots. Pools hold pool_size or
# pool_size - 1 teams, with the larger pools first. Accepts an injected RNG so a
# layout is reproducible.
class TeamPooler
  def initialize(team_category, random: Random.new)
    @team_category = team_category
    @random = random
    @pool_size = team_category.pool_size.to_i
    @teams = team_category.teams.order(:id).to_a
  end

  def set_pools
    return clear_pools! if @pool_size <= 1
    return if @teams.empty?

    pools = Array.new(pool_count) { [] }
    place_seeds(pools)
    draw_rest(pools)
    persist!(pools)
  end

  private attr_reader :team_category, :random, :teams, :pool_size

  private def pool_count
    [(teams.size.to_f / pool_size).ceil, 1].max
  end

  # Larger pools first: with N teams and P pools, the first (N mod P) pools hold
  # ceil, the rest floor. e.g. 11 teams, P=4 -> [3,3,3,2].
  private def target_sizes
    base, remainder = teams.size.divmod(pool_count)
    Array.new(pool_count) { |i| (i < remainder) ? base + 1 : base }
  end

  private def place_seeds(pools)
    seeded = teams.select { |t| t.seed.present? }.sort_by(&:seed)
    seeded.each_with_index { |team, i| pools[i % pool_count] << team }
  end

  private def draw_rest(pools)
    sizes = target_sizes
    unseeded = teams.reject { |t| t.seed.present? }.shuffle(random: random)
    unseeded.each do |team|
      pool_index = (0...pools.size).find { |i| pools[i].size < sizes[i] }
      pools[pool_index] << team
    end
  end

  private def persist!(pools)
    Team.transaction do
      pools.each_with_index do |members, i|
        members.each_with_index do |team, j|
          team.update!(pool_number: i + 1, pool_position: j + 1)
        end
      end
    end
  end

  private def clear_pools!
    Team.transaction do
      teams.each do |team|
        next if team.pool_number.nil? && team.pool_position.nil?

        team.update!(pool_number: nil, pool_position: nil)
      end
    end
  end
end
