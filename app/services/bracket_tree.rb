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

  # Units in a half holding `entries` competitors: entries in pairs, rounded UP
  # to a power of two so the half is a PERFECT tree — byes exist only in round 1
  # and no winner ever sits out a round once they have started fighting. A
  # ragged half would leave one unit a level shallower and its winner skipping a
  # round, which is what the organizers never draw.
  #
  # The cost is byes, and both seeders accept it: a later-round skip is worse
  # than a first-round bye, and a bye is what every poster uses to absorb an
  # awkward field size.
  def self.half_size(entries)
    1 << ([(entries / 2.0).ceil, 1].max - 1).bit_length
  end

  # Every internal node of `shape`, in-order — which is top to bottom — as
  # {parent_1:, parent_2:, round:}. A parent is either a leaf INDEX into the
  # unit list or an earlier node of this list.
  #
  # `round` is the COLUMN the node sits in, max(parent rounds) + 1, so a round-1
  # unit may feed a node several columns to its right. Both builders persist
  # these in order, so the round rule and the top-to-bottom ordering are stated
  # once, next to the shape that determines them.
  def self.internal_nodes(shape)
    return [] unless shape.is_a?(Array)

    walk(shape).last
  end

  # Resolves a parent reference from `internal_nodes`: a leaf index against the
  # caller's round-1 records, or an internal node against the record the caller
  # stored on it. Children are created after their parents, so it is always
  # there — `fetch` says so rather than passing a nil parent to `create!`.
  def self.parent_record(parent, leaves)
    parent.is_a?(Integer) ? leaves[parent] : parent.fetch(:record)
  end

  # Returns [subtree root, its round, the subtree's internal nodes in-order].
  private_class_method def self.walk(shape)
    return [shape, 1, []] if shape.is_a?(Integer)

    left, left_round, left_nodes = walk(shape.first)
    right, right_round, right_nodes = walk(shape.last)
    node = {parent_1: left, parent_2: right, round: [left_round, right_round].max + 1}

    [node, node[:round], left_nodes + [node] + right_nodes]
  end
end
