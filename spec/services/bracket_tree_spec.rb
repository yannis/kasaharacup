# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketTree do
  describe ".split" do
    it "returns a bare leaf for a single index" do
      expect(described_class.split([3], ceil_first: true)).to eq 3
    end

    it "takes the ceil half first when asked" do
      expect(described_class.split([0, 1, 2], ceil_first: true)).to eq [[0, 1], 2]
    end

    it "takes the floor half first when mirrored" do
      expect(described_class.split([0, 1, 2], ceil_first: false)).to eq [0, [1, 2]]
    end
  end

  describe ".shape" do
    it "has no shape for an empty field" do
      expect(described_class.shape(0, 0)).to be_nil
    end

    it "returns a bare leaf for a single unit" do
      expect(described_class.shape(0, 1)).to eq 0
      expect(described_class.shape(1, 0)).to eq 0
    end

    it "builds a balanced tree when both halves are powers of two" do
      expect(described_class.shape(2, 2)).to eq [[0, 1], [2, 3]]
    end

    # The 2025 Ladies category (9 pools, 18 qualifiers) as the design spec
    # draws it: (((A | B) | C) | (D | E)) over the top half, mirrored below.
    it "reproduces the Ladies split from the design spec" do
      expect(described_class.shape(5, 5)).to eq [
        [[[0, 1], 2], [3, 4]],
        [[5, 6], [7, [8, 9]]]
      ]
    end

    it "gives every unit exactly one leaf, for every pair of half sizes" do
      (0..8).to_a.product((0..8).to_a).each do |top, bottom|
        next if (top + bottom).zero?

        expect(flatten_leaves(described_class.shape(top, bottom))).to eq((0...(top + bottom)).to_a),
          "halves #{top}/#{bottom}"
      end
    end

    # Every internal node has exactly two parents — the property the builders
    # rely on to keep parent_*_1 and parent_*_2 both set.
    it "never produces a one-parent node" do
      # From 2: a single unit is a bare leaf with no internal node to check, and
      # `all` over an empty list passes without asserting anything. The
      # non-empty check keeps it that way if the shape ever changes.
      (2..12).each do |total|
        nodes = branches(described_class.shape((total / 2.0).ceil, total / 2))

        expect(nodes).not_to be_empty, "total #{total} checked no node at all"
        expect(nodes).to all(have_attributes(size: 2)), "total #{total}"
      end
    end

    def flatten_leaves(shape)
      return [] if shape.nil?
      return [shape] if shape.is_a?(Integer)

      shape.flat_map { |part| flatten_leaves(part) }
    end

    def branches(shape)
      return [] if shape.is_a?(Integer) || shape.nil?

      [shape] + shape.flat_map { |part| branches(part) }
    end
  end
end
