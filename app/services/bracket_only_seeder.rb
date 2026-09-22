# frozen_string_literal: true

# Classic single-elimination draw for a bracket-only team category (no pool
# phase). Returns ordered round-1 pairs [team_or_nil, team_or_nil] (nil = a
# bye), the same shape as BracketSeeder#first_round_pairs.
#
# NOT built on BracketSeeder: its pairing math assumes complete rank layers
# (every pool number present at every rank it is fed), which bracket-only
# input cannot satisfy, so this is a dedicated draw.
#
# teams.seed is an ordering hint, not an identifier: seeds order by [seed, id]
# (lower = stronger; the id tie-break makes duplicate values deterministic).
# Byes go to seeds first, then to randomly drawn unseeded teams. Units holding
# a seed take the standard protected positions (top, bottom, quarter
# boundaries, ...); the rest fill the remaining positions at random.
class BracketOnlySeeder
  def initialize(teams, random: Random.new)
    @teams = teams.to_a
    @random = random
  end

  def first_round_pairs
    @first_round_pairs ||= (teams.size < 2) ? [] : place(bye_units + fight_units)
  end

  def bracket_size
    return 0 if teams.size < 2

    2**Math.log2(teams.size).ceil
  end

  # The tree built over first_round_pairs, as nested indices into it (see
  # BracketTree). The builders can no longer derive the shape by pairing
  # adjacent units, because the compact draw's halves are not the same size.
  def tree_shape
    @tree_shape ||= BracketTree.shape(*unit_half_sizes)
  end

  private attr_reader :teams, :random

  # Today's halves are equal powers of two; a later task replaces this with the
  # real per-half unit counts once the halves can differ.
  private def unit_half_sizes
    count = first_round_pairs.size
    [count / 2, count - count / 2]
  end

  # [seed, id] via Seedable, the one definition the panel and both poolers share.
  private def seeded
    @seeded ||= Team.in_seed_order(teams)
  end

  private def unseeded
    @unseeded ||= (teams - seeded).shuffle(random: random)
  end

  # Seeds first; remaining byes go to (already shuffled) unseeded teams.
  private def bye_teams
    @bye_teams ||= (seeded + unseeded).first(bracket_size - teams.size)
  end

  private def bye_units
    bye_teams.map { |team| [team, nil] }
  end

  # Each remaining seed fights an unseeded opponent while any remain; leftover
  # seeds (an all-seeded field) pair strongest vs weakest among themselves, and
  # leftover unseeded teams pair in their (random) draw order. The remainder
  # after byes is even (bracket_size - 2 * byes), so nobody is left over.
  private def fight_units
    seeds = seeded - bye_teams
    others = unseeded - bye_teams
    seed_fights = seeds.first(others.size).map { |seed| [seed, others.shift] }
    leftover_seeds = seeds.drop(seed_fights.size)
    seed_fights + strongest_vs_weakest(leftover_seeds) + others.each_slice(2).to_a
  end

  private def strongest_vs_weakest(list)
    (0...list.size / 2).map { |i| [list[i], list[list.size - 1 - i]] }
  end

  # Units holding a seed go to BracketPositions' protected positions in
  # seed-priority order, and remaining bye units take the next protected
  # positions — the sequence is maximally spread, so no two byes meet in round 2
  # unless byes outnumber the round-2 slots. Only fights get random positions.
  # (Seeded fight units and unseeded byes never coexist: byes go to seeds
  # first, so an unseeded bye implies every seed already holds one.)
  private def place(units)
    with_seed, rest = units.partition { |unit| seed_priority(unit) }
    byes, fights = rest.partition { |unit| unit.last.nil? }
    protected_units = with_seed.sort_by { |unit| seed_priority(unit) } + byes

    positions = Array.new(units.size)
    sequence = BracketPositions.spread_order(units.size)
    protected_units.each_with_index { |unit, i| positions[sequence[i]] = unit }
    open = (0...units.size).select { |i| positions[i].nil? }.shuffle(random: random)
    fights.each { |unit| positions[open.shift] = unit }
    positions
  end

  # A unit's priority is its strongest seed's index in the seed order.
  private def seed_priority(unit)
    unit.compact.filter_map { |team| seeded.index(team) }.min
  end
end
