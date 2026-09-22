# frozen_string_literal: true

# Step 3 of the compact draw: the recursive halving that turns an ordered list
# of round-1 units into a tree. Both seeders share it — they differ in how they
# ORDER the units, not in how the tree is built over them.
#
# A shape is nested [left, right] pairs of indices into the unit list; a bare
# Integer is a leaf (that unit). Splitting a list of two or more always yields
# two non-empty parts, so every internal node has exactly two parents — which is
# what lets the builders keep parent_*_1 and parent_*_2 both set, and every
# consumer of Encounter#bye? / Fight#bye? keep working.
module BracketTree
  # The whole tree. The top half splits ceil-half first and the bottom mirrors
  # it (floor-half first), so the two halves read as reflections of each other
  # the way a drawn poster does.
  def self.shape(top_count, bottom_count)
    total = top_count + bottom_count
    return nil if total.zero?

    top = (0...top_count).to_a
    bottom = (top_count...total).to_a
    return split(bottom, ceil_first: false) if top.empty?
    return split(top, ceil_first: true) if bottom.empty?

    [split(top, ceil_first: true), split(bottom, ceil_first: false)]
  end

  def self.split(indices, ceil_first:)
    return indices.first if indices.size == 1

    cut = ceil_first ? (indices.size / 2.0).ceil : indices.size / 2
    [split(indices.first(cut), ceil_first: ceil_first),
      split(indices.drop(cut), ceil_first: ceil_first)]
  end
end
