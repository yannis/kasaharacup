# frozen_string_literal: true

# Standard single-elimination position order: the unit positions of a bracket
# half (or a whole bracket), listed most-protected first — the classic layout
# where projected semifinals are 1v4 and 2v3 and quarterfinals 1v8/4v5/3v6/2v7.
#
# Taking the first N of the sequence gives N positions spread as widely as the
# bracket allows, so the units placed there meet each other as late as possible.
# BracketOnlySeeder uses it to protect seeds. The pooled BracketSeeder no longer
# does: its compact draw leaves at most one bye per half, with nothing to spread.
module BracketPositions
  # Build the replace-by-complement-pairs layout, mirror the bottom half so
  # seed 2 sits at the very bottom, then read off each seed's position.
  # `count` must be a power of two (a bracket half always is); anything else
  # has no such layout and used to come back quietly padded with nils.
  def self.spread_order(count)
    return [] if count < 1
    raise ArgumentError, "count must be a power of two, got #{count}" unless count.nobits?(count - 1)
    return [0] if count == 1

    layout = [1]
    while layout.size < count
      doubled = layout.size * 2
      layout = layout.flat_map { |seed| [seed, doubled + 1 - seed] }
    end
    half = count / 2
    layout = layout.first(half) + layout.last(half).reverse
    invert(layout)
  end

  # seed-at-position => position-of-seed, in one pass rather than a scan per seed.
  private_class_method def self.invert(layout)
    positions = Array.new(layout.size)
    layout.each_with_index { |seed, position| positions[seed - 1] = position }
    positions
  end
end
