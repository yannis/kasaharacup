# frozen_string_literal: true

# Standard single-elimination position order: the unit positions of a bracket
# half (or a whole bracket), listed most-protected first — the classic layout
# where projected semifinals are 1v4 and 2v3 and quarterfinals 1v8/4v5/3v6/2v7.
#
# Taking the first N of the sequence gives N positions spread as widely as the
# bracket allows, so the units placed there meet each other as late as possible.
# Both seeders use it: BracketOnlySeeder to protect seeds, BracketSeeder to
# spread byes.
module BracketPositions
  # Build the replace-by-complement-pairs layout, mirror the bottom half so
  # seed 2 sits at the very bottom, then read off each seed's position.
  # `count` is always a power of two (a bracket half always is).
  def self.spread_order(count)
    return [] if count < 1
    return [0] if count == 1

    layout = [1]
    layout = layout.flat_map { |seed| [seed, layout.size * 2 + 1 - seed] } while layout.size < count
    half = count / 2
    layout = layout.first(half) + layout.last(half).reverse
    (1..count).map { |seed| layout.index(seed) }
  end
end
