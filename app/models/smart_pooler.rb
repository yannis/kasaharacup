# frozen_string_literal: true

# Distributes a category's participants into pools, balancing four goals:
#
#   1. Randomness    - a different valid layout on every reset.
#   2. Club spread   - members of the same club land in different pools whenever
#                      possible (and are spread as evenly as possible when a club
#                      has more members than there are pools).
#   3. Grade balance - strength is spread evenly so no pool is all-strong or
#                      all-weak.
#   4. Seed spread   - the seeded go into pools that feed opposite halves of the
#                      bracket, so the top two meet no earlier than the final
#                      whenever both win their pools. A seed that only comes
#                      second is routed by its rank instead (see SeedPoolOrder),
#                      and can then meet the other in a semifinal.
#
# Strategy: the seeded go in first, into the pools SeedPoolOrder names, and
# never move again — neither the placing pass nor the repair may touch them.
# Then order the rest strongest-first (randomised within equal grades), and drop
# each into the weakest pool that still has room and does not already hold their
# club (LPT balancing + club-aware placement). That single pass is greedy, so a
# final repair pass trades clubmates apart where it painted itself into a
# corner.
#
# Pools number ceil(N / pool_size), so each holds either pool_size or
# pool_size - 1 participants with the fewest short pools possible. The short
# pools are spread evenly across the pool numbers (#1, then the head of each
# half/quarter) so the byes and easier pools the bracket builder derives from
# them are distributed across the bracket instead of clustered at the top.
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
    place_seeds
    ordered_participants.each { |participation| pick_pool(participation).participations << participation }
    repair_club_spread!
    persist!
  end

  private attr_reader :random, :target_sizes

  private def pool_count
    [(participants.size.to_f / pool_size).ceil, 1].max
  end

  private def build_empty_pools
    base, full_pools = participants.size.divmod(pool_count)
    short = short_pool_indices(pool_count - full_pools, pool_count)
    @poules = Array.new(pool_count) { Pool.new }
    @target_sizes = Array.new(pool_count) { |i| short.include?(i) ? base : base + 1 }
  end

  # Zero-based indices of the short pools, spread evenly across the pool numbers
  # so they head the bracket's halves/quarters instead of clustering at the top.
  # With P pools and k short pools the i-th sits at round(i * P / k): e.g. 12
  # pools with 2 short -> indices 0 and 6 -> pool numbers 1 and 7.
  private def short_pool_indices(count, total)
    return [] if count.zero?

    Array.new(count) { |i| (i * total.to_f / count).round }
  end

  # The seeded go in before anything else, into the pools SeedPoolOrder names,
  # so the pools feeding opposite halves of the bracket hold the top two seeds.
  # TeamPooler walks the same order through the same call.
  #
  # DELIBERATE: SeedPoolOrder always opens on pool 1, and short_pool_indices
  # always makes pool 1 one of the short pools when the sizes are uneven, so
  # seed 1 draws a short pool — one fight fewer on the way out. That is the
  # usual reading of a top seeding rather than an accident of the two rules
  # meeting, and the pooler spec pins it so it cannot change unnoticed.
  private def place_seeds
    SeedPoolOrder.assign(seeded.size, target_sizes).each_with_index do |index, i|
      poules[index].participations << seeded[i]
    end
  end

  private def seeded
    @seeded ||= Participation.in_seed_order(participants)
  end

  # Strongest first so LPT balancing spreads the top fighters across pools;
  # the random key shuffles fighters of equal grade. The seeded are already
  # placed and never move again.
  private def ordered_participants
    (participants - seeded).sort_by { |p| [-p.kenshi.grade.to_i, random.rand] }
  end

  private def pick_pool(participation)
    open = open_pools
    club = participation.kenshi.club
    candidates = club.present? ? open.reject { |pool| pool.contains_club?(club) } : open
    # No room left away from their club. The repair pass sorts out the ones that
    # only look unavoidable because of where earlier fighters already went.
    candidates = open if candidates.empty?
    candidates.min_by { |pool| [pool.total_dan, pool.participations.size, random.rand] }
  end

  # Placing fighters one at a time can paint the pass into a corner: once the
  # only pool with room already holds a fighter's club they collide, even though
  # trading places with someone in another pool would have separated them.
  # Trading rather than moving keeps every pool the size it was meant to be.
  private def repair_club_spread!
    while (trade = best_club_trade)
      crowded, duplicate, roomy, partner = trade
      crowded.participations[crowded.participations.index(duplicate)] = partner
      roomy.participations[roomy.participations.index(partner)] = duplicate
    end
  end

  # The trade that separates a badly spread club at the least cost to pool
  # strength. Weighing every available trade rather than taking the first one
  # found protects the balance the placing pass worked for.
  private def best_club_trade
    trades = poules.flat_map { |crowded|
      crowded_clubmates(crowded).flat_map { |duplicate|
        club = duplicate.kenshi.club
        poules.reject { |roomy| roomy.equal?(crowded) || roomy.contains_club?(club) }
          .flat_map { |roomy|
            trade_partners(roomy, crowded, duplicate).map { |partner| [crowded, duplicate, roomy, partner] }
          }
      }
    }
    trades.min_by { |crowded, duplicate, roomy, partner|
      [dan_spread_after(crowded, roomy, duplicate, partner), random.rand]
    }
  end

  # Everyone in this pool whose club another of its members also belongs to —
  # minus the seeded, who are pinned. The rejection comes AFTER the grouping on
  # purpose: a seed still counts towards its club's presence, so a seed and a
  # clubmate are a collision, and the clubmate is the one offered up for trade.
  private def crowded_clubmates(pool)
    pool.participations
      .select { |participation| participation.kenshi.club.present? }
      .group_by { |participation| participation.kenshi.club }
      .select { |_club, members| members.size > 1 }
      .flat_map { |_club, members| members }
      .reject(&:seeded?)
  end

  # Who the duplicate can trade with: anyone unseeded whose own club is absent
  # from the crowded pool once the duplicate leaves it, so the trade cannot
  # introduce a fresh collision of its own. A seed is never traded in, which
  # can leave a collision unrepaired — the pinning is worth more. Two seeded
  # clubmates sharing a pool (only reachable when the seeds outnumber the pools
  # and the order wraps) are left alone for the same reason: neither half of
  # that pair may move.
  private def trade_partners(roomy, crowded, duplicate)
    staying = crowded.participations - [duplicate]
    roomy.participations.reject { |candidate|
      candidate.seeded? ||
        (candidate.kenshi.club.present? &&
          staying.any? { |other| other.kenshi.club == candidate.kenshi.club })
    }
  end

  # How uneven the pools' strength would be after a trade. Only the two pools
  # involved move, by the difference between the two fighters' grades.
  private def dan_spread_after(crowded, roomy, duplicate, candidate)
    shift = candidate.kenshi.grade.to_i - duplicate.kenshi.grade.to_i
    totals = poules.map(&:total_dan)
    totals[poules.index(crowded)] += shift
    totals[poules.index(roomy)] -= shift
    totals.max - totals.min
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
