# frozen_string_literal: true

# Standard single-elimination position order: the unit positions of a bracket
# half (or a whole bracket), listed most-protected first — the classic layout
# where projected semifinals are 1v4 and 2v3 and quarterfinals 1v8/4v5/3v6/2v7.
#
# It reads that layout off the tree BracketTree.shape built, so it fits a
# compact draw as well as a power-of-two one. Taking the first N of the sequence
# gives N positions spread as widely as the tree allows, so the units placed
# there meet each other as late as possible. BracketOnlySeeder uses it to
# protect seeds. The pooled BracketSeeder no longer does: its compact draw
# leaves at most one bye per half, with nothing to spread.
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

  # The bottom half is mirrored so seed 2 sits at the very bottom of the column
  # rather than just below the middle — the classic layout, and the one the
  # power-of-two sequences this replaces encoded by reversing their lower half.
  private_class_method def self.protected_order(shape, mirror:)
    return [shape] if shape.is_a?(Integer)

    first, second = mirror ? [shape.last, shape.first] : shape
    snake(protected_order(first, mirror: mirror), protected_order(second, mirror: mirror))
  end

  private_class_method def self.snake(low, high)
    blocks = [low.dup, high.dup]
    Array.new(low.size + high.size) do |index|
      block = blocks[SNAKE[index % 4]]
      block = blocks.find(&:any?) if block.empty?
      block.shift
    end
  end
end
