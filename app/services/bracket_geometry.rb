# frozen_string_literal: true

# Where a bracket node sits vertically, and which round-1 units feed it, read
# from the PARENT LINKS rather than from `2 ** (round - 1)` and `position`.
#
# That closed form only holds for a tree padded to a power of two. The compact
# draw leaves round-1 units at different depths, so every consumer of the shape
# — the on-screen layout and both printable trees — reads it from here instead,
# and there is one definition rather than three copies that cannot drift apart
# without someone noticing.
#
# Built with the node list and a block returning a node's parents, so it serves
# Encounters, Fights and anything else with the same shape.
class BracketGeometry
  def initialize(nodes, &parents_of)
    @nodes = nodes
    @parents_of = parents_of
    @slot_centers = {}
    @leaf_positions = {}
  end

  # A node's vertical centre, measured in round-1 slots from the top. A round-1
  # node sits on its own index in the column; an internal node on the midpoint
  # of its parents'. On a full tree this returns exactly what the old
  # (position - 1) * span + (span - 1) / 2.0 returned.
  def slot_center(node)
    @slot_centers[node.id] ||= begin
      parents = parents_of(node)
      if parents.empty?
        leaf_index(node).to_f
      else
        parents.sum { |parent| slot_center(parent) } / parents.size
      end
    end
  end

  # The `position` of every round-1 unit beneath a node — what the PDFs
  # paginate on. A round-1 node is its own leaf.
  def leaf_positions(node)
    @leaf_positions[node.id] ||= begin
      parents = parents_of(node)
      parents.empty? ? [node.position] : parents.flat_map { |parent| leaf_positions(parent) }
    end
  end

  private def parents_of(node)
    @parents_of.call(node).compact
  end

  # Defaults rather than raises: callers pass the category's whole node list, so
  # every parentless node is indexed. A filtered list would silently stack its
  # unindexed nodes on slot 0 — if that ever happens, the assumption above is
  # what broke.
  private def leaf_index(node)
    leaf_indexes.fetch(node.id, 0)
  end

  # Round-1 units read down the column in `position` order; that ordering is
  # the builders' job, and this only follows it.
  private def leaf_indexes
    @leaf_indexes ||= @nodes.select { |node| parents_of(node).empty? }
      .sort_by { |node| node.position.to_i }
      .each_with_index
      .to_h { |node, index| [node.id, index] }
  end
end
