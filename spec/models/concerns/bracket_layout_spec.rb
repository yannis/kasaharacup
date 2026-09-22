# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketLayout do
  # The smallest thing that satisfies the concern's contract.
  def layout_for(nodes)
    Class.new do
      include BracketLayout

      def initialize(nodes) = @nodes = nodes

      def bracket_nodes = @nodes

      def node_parents(node) = node.parents

      def node_has_own_identity?(_node) = true
    end.new(nodes)
  end

  def node(id, round, position, parents = [])
    Struct.new(:id, :round, :position, :parents).new(id, round, position, parents)
  end

  # A round-1 leaf beside a sub-tree feeds a round-3 node, so its connector
  # spans two columns. The elbow has to sit in the gap beside the CHILD: the
  # midpoint between the two lands at x = 392, inside the 280..504 band where
  # round-2 cards are drawn, and the line would be stroked through them.
  it "elbows beside the child when a connector spans two columns" do
    a = node(1, 1, 1)
    b = node(2, 1, 2)
    c = node(3, 1, 3)
    ab = node(4, 2, 1, [a, b])
    root = node(5, 3, 1, [ab, c])
    layout = layout_for([a, b, c, ab, root])

    root_paths = layout.connector_paths.select { |path| path.include?("H #{layout.match_left(root)}") }

    expect(root_paths).not_to be_empty
    expect(root_paths).to all include("H #{layout.match_left(root) - BracketLayout::ROUND_GAP / 2} ")
  end

  it "keeps a one-column connector where it has always been" do
    a = node(1, 1, 1)
    b = node(2, 1, 2)
    parent = node(3, 2, 1, [a, b])
    layout = layout_for([a, b, parent])

    expect(layout.connector_paths.first).to start_with "M 232 "
    expect(layout.connector_paths.first).to include " H 256 "
  end
end
