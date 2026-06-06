# frozen_string_literal: true

# Distributes a category's participants into pools, balancing three goals:
#
#   1. Randomness    - a different valid layout on every reset.
#   2. Club spread   - members of the same club land in different pools whenever
#                      possible (and are spread as evenly as possible when a club
#                      has more members than there are pools).
#   3. Grade balance - strength is spread evenly so no pool is all-strong or
#                      all-weak.
#
# Strategy: order participants strongest-first (randomised within equal grades),
# then drop each into the weakest pool that still has room and does not already
# hold their club (LPT balancing + club-aware placement).
#
# Pools number ceil(N / pool_size), so each holds either pool_size or
# pool_size - 1 participants with the fewest short pools possible. The short
# pools take the lowest pool numbers, which the bracket builder seeds at the top
# of the quarter/semi tree.
class SmartPooler
  attr_reader :category, :participants, :poules, :pool_size

  def initialize(category, random: Random.new)
    @category = category
    @random = random
    @pool_size = category.pool_size
    # Stable id order keeps results reproducible for a given random seed.
    @participants = category.participations.includes(kenshi: :club).order(:id).to_a
    @poules = []
  end

  def set_pools
    return clear_pools! if pool_size.to_i <= 1
    return if participants.empty?

    build_empty_pools
    ordered_participants.each { |participation| pick_pool(participation).participations << participation }
    persist!
  end

  private attr_reader :random, :target_sizes

  private def pool_count
    [(participants.size.to_f / pool_size).ceil, 1].max
  end

  private def build_empty_pools
    base, full_pools = participants.size.divmod(pool_count)
    short_pools = pool_count - full_pools
    @poules = Array.new(pool_count) { Pool.new }
    # Short pools first so they take the lowest pool numbers (top of the bracket).
    @target_sizes = Array.new(pool_count) { |i| (i < short_pools) ? base : base + 1 }
  end

  # Strongest first so LPT balancing spreads the top fighters across pools;
  # the random key shuffles fighters of equal grade.
  private def ordered_participants
    participants.sort_by { |p| [-p.kenshi.grade.to_i, random.rand] }
  end

  private def pick_pool(participation)
    open = open_pools
    club = participation.kenshi.club
    candidates = club.present? ? open.reject { |pool| pool.contains_club?(club) } : open
    candidates = open if candidates.empty? # club collision unavoidable
    candidates.min_by { |pool| [pool.total_dan, pool.participations.size, random.rand] }
  end

  private def open_pools
    poules.select.with_index { |pool, i| pool.participations.size < target_sizes[i] }
  end

  private def persist!
    Participation.transaction do
      poules.each_with_index do |pool, i|
        pool.participations.each_with_index do |participation, j|
          participation.update!(pool_number: i + 1, pool_position: j + 1)
        end
      end
    end
  end

  private def clear_pools!
    Participation.transaction do
      participants.each do |participation|
        next if participation.pool_number.nil? && participation.pool_position.nil?

        participation.update!(pool_number: nil, pool_position: nil)
      end
    end
  end
end
