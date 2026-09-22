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
# The field splits in two and each half is drawn by recursive halving rather
# than padded to a power of two, so byes are POSITIONAL: a half whose entries
# are odd gives its outermost unit a bye, and a half whose entries are even
# gives none — at most two in the whole draw, where the padded bracket drawn
# for a field of nine scheduled seven. The seeds still collect those byes,
# because a half's outermost unit is also its most-protected position and the
# seeds take the protected positions first; the rest of the field fills what is
# left.
class BracketOnlySeeder
  def initialize(teams, random: Random.new)
    @teams = teams.to_a
    @random = random
  end

  def first_round_pairs
    @first_round_pairs ||= build_units
  end

  # The tree built over first_round_pairs, as nested indices into it (see
  # BracketTree). The builders can no longer derive the shape by pairing
  # adjacent units, because the compact draw's halves are not the same size.
  def tree_shape
    @tree_shape ||= BracketTree.shape(*unit_halves)
  end

  private attr_reader :teams, :random

  # Seeds take the most-protected units one apiece, then the rest of the field
  # fills what is left, least-protected unit first. The capacities sum to the
  # field size, so every unit is filled whichever way round we go; going
  # backwards is what gives the strongest unit the weakest team still in the
  # draw, so an all-seeded field pairs 1v4 and 2v3 rather than 1v3 and 2v4.
  # A half's bye unit holds one team rather than two, and those units are the
  # first the protected order hands out — which is how the seeds still end up
  # with the byes.
  private def build_units
    return [] if teams.size < 2
    return [drawn.first(2)] if teams.size == 2

    caps = capacities
    units = Array.new(caps.size) { [] }
    order = BracketPositions.spread_order(tree_shape)

    drawn.first(order.size).each_with_index { |team, index| units[order[index]] << team }
    rest = drawn.drop(order.size)
    order.reverse_each do |position|
      units[position] << rest.shift while units[position].size < caps[position] && rest.any?
    end
    units.map { |members| [members[0], members[1]] }
  end

  # The draw order: seeds strongest first, then the shuffled unseeded.
  private def drawn
    @drawn ||= seeded + unseeded
  end

  # How many teams each unit holds: one for a bye unit, two for a fight.
  # The capacities sum to the field size, so the draw fills exactly.
  private def capacities
    top_byes, bottom_byes = bye_units
    top = Array.new(units_per_half) { |unit| top_byes.include?(unit) ? 1 : 2 }
    bottom = Array.new(units_per_half) { |unit| bottom_byes.include?(unit) ? 1 : 2 }
    top + bottom
  end

  # Which units hold a bye, most-protected first, so the seeds take them and no
  # two byes meet earlier than the half allows. Mirrors BracketSeeder.
  private def bye_units
    @bye_units ||= begin
      order = BracketPositions.spread_order(BracketTree.shape(units_per_half, units_per_half))
      [order.select { |unit| unit < units_per_half }.first(2 * units_per_half - top_entries).sort,
        order.filter_map { |unit| unit - units_per_half if unit >= units_per_half }
          .first(2 * units_per_half - bottom_entries).sort]
    end
  end

  # Units per half, as [top, bottom]. Under three teams there is nothing to
  # halve: an empty field is no tree, and a two-team field is the single fight
  # build_units carves out — halving would instead give each half a bye and draw
  # a final between them. Same base case as BracketSeeder.
  private def unit_halves
    return [0, 0] if teams.size < 2
    return [0, 1] if teams.size == 2

    [units_per_half, units_per_half]
  end

  # A power of two, so each half is a PERFECT tree and no winner ever sits out a
  # round once they have started fighting. Byes absorb the awkward field sizes,
  # exactly as they do for a pooled category.
  private def units_per_half
    @units_per_half ||= 2**Math.log2([(top_entries / 2.0).ceil, 1].max).ceil
  end

  private def top_entries = (teams.size / 2.0).ceil

  private def bottom_entries = teams.size / 2

  # [seed, id] via Seedable, the one definition the panel and both poolers share.
  private def seeded
    @seeded ||= Team.in_seed_order(teams)
  end

  private def unseeded
    @unseeded ||= (teams - seeded).shuffle(random: random)
  end
end
