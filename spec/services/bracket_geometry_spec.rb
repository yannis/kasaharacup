# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketGeometry do
  # A stand-in node: the geometry only needs #id, #position and its parents.
  # Built through a method rather than a constant, which inside a describe
  # block would be assigned on Object and leak into every other spec file.
  def node(id, position, parents = [])
    Struct.new(:id, :position, :parents).new(id, position, parents)
  end

  def geometry(nodes)
    described_class.new(nodes) { |item| item.parents }
  end

  it "puts round-1 nodes on consecutive slots in position order" do
    a = node(1, 1)
    b = node(2, 2)

    expect(geometry([a, b]).slot_center(a)).to eq 0.0
    expect(geometry([a, b]).slot_center(b)).to eq 1.0
  end

  it "centres an internal node between its parents" do
    a = node(1, 1)
    b = node(2, 2)
    parent = node(3, 1, [a, b])

    expect(geometry([a, b, parent]).slot_center(parent)).to eq 0.5
  end

  # The case the old 2 ** (round - 1) formula cannot express: a leaf feeding a
  # node two columns to its right, beside a sub-tree of its own.
  it "centres a ragged node between a leaf and a sub-tree" do
    a = node(1, 1)
    b = node(2, 2)
    c = node(3, 3)
    ab = node(4, 1, [a, b])
    root = node(5, 1, [ab, c])

    expect(geometry([a, b, c, ab, root]).slot_center(root)).to eq 1.25
  end

  it "reproduces the power-of-two formula on a full tree" do
    leaves = (1..4).map { |i| node(i, i) }
    left = node(5, 1, leaves.first(2))
    right = node(6, 2, leaves.last(2))
    root = node(7, 1, [left, right])
    all = leaves + [left, right, root]

    # Old rule: (position - 1) * span + (span - 1) / 2.0
    expect(geometry(all).slot_center(left)).to eq 0.5
    expect(geometry(all).slot_center(right)).to eq 2.5
    expect(geometry(all).slot_center(root)).to eq 1.5
  end

  describe "#leaf_positions" do
    it "returns a round-1 node's own position" do
      a = node(1, 7)

      expect(geometry([a]).leaf_positions(a)).to eq [7]
    end

    it "gathers every round-1 position beneath a node" do
      a = node(1, 1)
      b = node(2, 2)
      c = node(3, 3)
      ab = node(4, 1, [a, b])
      root = node(5, 1, [ab, c])

      expect(geometry([a, b, c, ab, root]).leaf_positions(root)).to contain_exactly(1, 2, 3)
    end
  end
end
