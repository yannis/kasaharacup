# frozen_string_literal: true

# Standard single-elimination position order: the unit positions of a bracket
# half (or a whole bracket), listed most-protected first — the classic layout
# where projected semifinals are 1v4 and 2v3 and quarterfinals 1v8/4v5/3v6/2v7.
#
# It reads that layout off the tree BracketTree.shape built, so it fits a
# compact draw as well as a power-of-two one. Taking the first N of the sequence
# gives N positions spread as widely as the tree allows, so the units placed
# there meet each other as late as possible — which is what both seeders use to
# place byes, and what BracketOnlySeeder additionally uses to protect seeds.
module BracketPositions
  # low, high, high, low — repeated.
  SNAKE = [0, 1, 1, 0].freeze
  private_constant :SNAKE

  # Unit positions, most-protected first, over the tree BracketTree.shape built.
  # Taking the first N gives N units as far apart as the tree allows, so the
  # units placed there meet each other as late as possible.
  def self.spread_order(shape)
    return [] if shape.nil?
    return [shape] if shape.is_a?(Integer)

    top, bottom = shape
    snake(protected_order(top, mirror: false), protected_order(bottom, mirror: true))
  end

  # The units holding a bye in each half, as indices within that half. A half of
  # `units` units seats 2 * units competitors, so whatever it holds short of
  # that it gives away as byes — taken most-protected first, so the byes are
  # spread as widely as the half allows and meet each other as late as it can
  # manage. Where byes outnumber the units' round-2 pairings they must meet
  # earlier; nothing can be done about that.
  #
  # The two halves take separate entry counts because a bracket-only field of
  # odd size splits unevenly; a pooled draw passes the same count twice.
  def self.bye_units(units, top_entries, bottom_entries)
    top_order, bottom_order = half_orders(units)

    [top_order.first(2 * units - top_entries).sort,
      bottom_order.first(2 * units - bottom_entries).sort]
  end

  # Each half's unit positions, most-protected first, renumbered from 0 within
  # that half.
  def self.half_orders(units)
    top, bottom = spread_order(BracketTree.shape(units, units)).partition { |unit| unit < units }

    [top, bottom.map { |unit| unit - units }]
  end

  # The bottom half is mirrored so seed 2 sits at the very bottom of the column
  # rather than just below the middle — the classic layout, and the one the
  # power-of-two sequences this replaces encoded by reversing their lower half.
  #
  # Public because SeedPoolOrder orders each half of the POOL numbers by the
  # same recursion: seeding and the draw must read one layout, or a category is
  # seeded for a tree the bracket does not build and nothing fails to say so.
  def self.protected_order(shape, mirror:)
    return [shape] if shape.is_a?(Integer)

    first, second = mirror ? [shape.last, shape.first] : shape
    snake(protected_order(first, mirror: mirror), protected_order(second, mirror: mirror))
  end

  # Interleaves two orders low/high/high/low, taking from whichever side still
  # has entries when the other runs out — the two sides differ in length for an
  # odd count. Public for the same reason protected_order is.
  def self.snake(low, high)
    blocks = [low.dup, high.dup]
    Array.new(low.size + high.size) do |index|
      block = blocks[SNAKE[index % 4]]
      block = blocks.find(&:any?) if block.empty?
      block.shift
    end
  end
end
