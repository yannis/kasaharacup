# frozen_string_literal: true

require "rails_helper"

RSpec.describe SeedOrderMove do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 4) }
  let(:sequence) { (1..).each }

  def participant(seed: nil)
    n = sequence.next
    kenshi = create(:kenshi, cup: cup, first_name: "First#{n}", last_name: "Last#{n}")
    create(:participation, category: category, kenshi: kenshi, seed: seed)
  end

  # The seeded, in seed order, as names — the panel's reading of the list.
  def order
    category.participations.where.not(seed: nil).sort_by { |p| [p.seed, p.id] }.map(&:seed)
  end

  def seeds_by_id
    category.participations.where.not(seed: nil).to_h { |p| [p.id, p.seed] }
  end

  describe "#call" do
    it "seeds an unseeded participation at the end of the list" do
      a = participant(seed: 1)
      b = participant

      described_class.new(participation: b, to_position: 2).call

      expect(seeds_by_id).to eq(a.id => 1, b.id => 2)
    end

    it "moves a seed up and pushes the ones it passes down" do
      a = participant(seed: 1)
      b = participant(seed: 2)
      c = participant(seed: 3)
      d = participant(seed: 4)

      described_class.new(participation: d, to_position: 2).call

      expect(seeds_by_id).to eq(a.id => 1, d.id => 2, b.id => 3, c.id => 4)
    end

    # The target is the position it ends up holding, so a caller dragging
    # downwards needs no off-by-one of its own.
    it "moves a seed down to exactly the position asked for" do
      a = participant(seed: 1)
      b = participant(seed: 2)
      c = participant(seed: 3)
      d = participant(seed: 4)

      described_class.new(participation: b, to_position: 4).call

      expect(seeds_by_id).to eq(a.id => 1, c.id => 2, d.id => 3, b.id => 4)
    end

    it "unseeds on a nil position and closes the gap" do
      a = participant(seed: 1)
      b = participant(seed: 2)
      c = participant(seed: 3)

      described_class.new(participation: b, to_position: nil).call

      expect(b.reload.seed).to be_nil
      expect(seeds_by_id).to eq(a.id => 1, c.id => 2)
    end

    it "leaves the list contiguous at 1..N after every kind of change" do
      a = participant(seed: 1)
      b = participant(seed: 2)
      c = participant

      described_class.new(participation: c, to_position: 3).call
      described_class.new(participation: c, to_position: 1).call
      described_class.new(participation: a, to_position: nil).call

      expect(order).to eq [1, 2]
      expect(seeds_by_id).to eq(c.id => 1, b.id => 2)
    end

    # Destroying a seeded participation in ActiveAdmin leaves a gap, and the
    # panel's "add" sends N + 1, which can collide with a value already there.
    it "heals a list left non-contiguous by a destroyed participation" do
      a = participant(seed: 1)
      b = participant(seed: 3)
      c = participant

      described_class.new(participation: c, to_position: 3).call

      expect(seeds_by_id).to eq(a.id => 1, b.id => 2, c.id => 3)
    end

    it "clamps a position past the end of the list" do
      a = participant(seed: 1)
      b = participant

      described_class.new(participation: b, to_position: 99).call

      expect(seeds_by_id).to eq(a.id => 1, b.id => 2)
    end

    it "clamps a position below the start of the list" do
      a = participant(seed: 1)
      b = participant(seed: 2)

      described_class.new(participation: b, to_position: 0).call

      expect(seeds_by_id).to eq(b.id => 1, a.id => 2)
    end

    it "returns the renumbered list in seed order" do
      a = participant(seed: 1)
      b = participant

      result = described_class.new(participation: b, to_position: 2).call

      expect(result.map(&:id)).to eq [a.id, b.id]
    end
  end
end
