# frozen_string_literal: true

require "rails_helper"

# Run against BOTH record types. The whole point of the concern is that the
# move service can be written once, so every example here has to hold for an
# Encounter and for a Fight or the service will drift apart in practice while
# looking shared on paper.
RSpec.describe BracketSlots do
  let(:cup) { create(:cup) }

  shared_examples "a bracket slot holder" do
    describe "#slot_entry" do
      it "is nil for an empty slot" do
        expect(record_with(slot_1: nil, slot_2: nil).slot_entry(1)).to be_nil
      end

      it "carries the descriptor alone before the pools have finished" do
        record = record_with(slot_1: {pool_number: 3, pool_rank: 2}, slot_2: nil)

        expect(record.slot_entry(1)).to have_attributes(
          pool_number: 3, pool_rank: 2, competitor: nil
        )
        expect(record.slot_entry(1).key).to eq "3.2"
      end

      it "carries the competitor resolved behind the descriptor" do
        record = record_with(slot_1: {pool_number: 3, pool_rank: 2, competitor: competitor_a}, slot_2: nil)

        expect(record.slot_entry(1).competitor).to eq competitor_a
      end
    end

    describe "#slot_occupied?" do
      # THE trap of this whole feature. A pooled bracket drawn before the pools
      # finish holds labels and no competitors; reading occupancy off the
      # competitor would make every unit a bye and offer the admin a tree of
      # empty slots.
      it "is true for a slot holding a label and nobody" do
        record = record_with(slot_1: {pool_number: 3, pool_rank: 2}, slot_2: nil)

        expect(record.slot_occupied?(1)).to be true
        expect(record.slot_occupied?(2)).to be false
      end

      it "agrees with #bye_slot" do
        record = record_with(slot_1: {pool_number: 3, pool_rank: 2}, slot_2: nil)

        expect(record.bye_slot).to eq 1
      end
    end

    describe "#entry_slot_for" do
      it "finds the slot holding an entry key" do
        record = record_with(slot_1: {pool_number: 3, pool_rank: 2},
          slot_2: {pool_number: 5, pool_rank: 1})

        expect(record.entry_slot_for("5.1")).to eq 2
        expect(record.entry_slot_for("9.9")).to be_nil
      end
    end
  end

  context "on Encounter" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }
    let(:competitor_a) { create(:team, team_category: category) }

    def record_with(slot_1:, slot_2:)
      attrs = {team_category: category, pool_number: nil, round: 1, position: 1, number: 1}
      [[1, slot_1], [2, slot_2]].each do |slot, spec|
        next if spec.nil?

        attrs[:"team_#{slot}_pool_number"] = spec[:pool_number]
        attrs[:"team_#{slot}_pool_rank"] = spec[:pool_rank]
        attrs[:"team_#{slot}_id"] = spec[:competitor]&.id
      end
      Encounter.create!(attrs)
    end

    it_behaves_like "a bracket slot holder"
  end

  context "on Fight" do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }
    let(:competitor_a) { create(:participation, category: category).kenshi }

    def record_with(slot_1:, slot_2:)
      attrs = {individual_category: category, pool_number: nil, round: 1, position: 1,
               number: 1, fighter_type: "Kenshi"}
      [[1, slot_1], [2, slot_2]].each do |slot, spec|
        next if spec.nil?

        attrs[:"fighter_#{slot}_pool_number"] = spec[:pool_number]
        attrs[:"fighter_#{slot}_pool_rank"] = spec[:pool_rank]
        attrs[:"fighter_#{slot}_id"] = spec[:competitor]&.id
      end
      Fight.create!(attrs)
    end

    it_behaves_like "a bracket slot holder"
  end
end
