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

    describe "#assign_slot_entry" do
      it "writes the descriptor and the competitor together" do
        record = record_with(slot_1: nil, slot_2: nil)
        entry = BracketEntry.for(pool_number: 4, pool_rank: 1, competitor: competitor_a)

        expect(record.assign_slot_entry(1, entry)).to be true

        record.reload
        expect(record.slot_entry(1)).to have_attributes(
          pool_number: 4, pool_rank: 1, competitor: competitor_a
        )
      end

      # The case Encounter#assign_team_to_slot cannot serve: its opening
      # `return if <id column> == team&.id` reads true when both ids are nil,
      # which is every move made before the pools have finished.
      it "moves a label-only entry, where no competitor id changes" do
        record = record_with(slot_1: {pool_number: 3, pool_rank: 2}, slot_2: nil)

        expect(record.assign_slot_entry(1, BracketEntry.for(pool_number: 5, pool_rank: 1, competitor: nil)))
          .to be true

        expect(record.reload.slot_entry(1).key).to eq "5.1"
      end

      it "clears both descriptor columns when the entry goes" do
        record = record_with(slot_1: {pool_number: 3, pool_rank: 2, competitor: competitor_a},
          slot_2: {pool_number: 5, pool_rank: 1})

        record.clear_slot(1)

        record.reload
        expect(record.slot_entry(1)).to be_nil
        expect(record.slot_occupied?(1)).to be false
      end

      it "reports false and writes nothing when the entry is already there" do
        record = record_with(slot_1: {pool_number: 3, pool_rank: 2}, slot_2: nil)
        entry = record.slot_entry(1)

        expect { expect(record.assign_slot_entry(1, entry)).to be false }
          .not_to(change { record.reload.updated_at })
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

  # Only Encounter forward-propagates into child slots, so only Encounter can
  # leave a stale one behind. On Fight the child reads its fighters lazily and
  # #refresh_child_slot_from_bye is a documented no-op.
  describe "a unit whose bye-ness changes (Encounter)" do
    let(:category) { create(:team_category, cup: cup, pool_size: nil) }

    def build_bracket(team_count)
      create_list(:team, team_count, team_category: category)
      TeamCategoryBracketBuilder.new(category, random: Random.new(1)).call
      category.bracket_encounters.where(round: 1).order(:position).to_a
    end

    # create_parent_rounds seeds a bye's occupant straight into the child at
    # build time. Fill the bye's empty side and the unit is a fight, so nobody
    # advances from it yet — but the child is still holding the seed.
    it "clears the child slot when a bye becomes a fight" do
      round_one = build_bracket(3)
      bye = round_one.detect(&:bye?)
      final = category.bracket_encounters.find_by(round: 2)
      child_slot = (final.parent_encounter_1_id == bye.id) ? 1 : 2
      expect(final.public_send(:"team_#{child_slot}_id")).to eq bye.bye_team.id

      empty_slot = (bye.bye_slot == 1) ? 2 : 1
      newcomer = create(:team, team_category: category)
      bye.assign_slot_entry(empty_slot, BracketEntry.for(pool_number: nil, pool_rank: nil, competitor: newcomer))

      expect(final.reload.public_send(:"team_#{child_slot}_id")).to be_nil
    end

    # This one is already carried by #propagate_bye_to_children — clearing an
    # occupied slot DOES change a team id, so its guard sees the change and
    # fires. Kept as a regression guard on that callback, not as cover for
    # #refresh_child_slot_from_bye: it passes with the hook disabled, where the
    # other two examples here do not.
    it "seeds the child slot when a fight becomes a bye" do
      round_one = build_bracket(4)
      unit = round_one.first
      final = category.bracket_encounters.find_by(round: 2)
      child_slot = (final.parent_encounter_1_id == unit.id) ? 1 : 2
      survivor = unit.team_1

      unit.clear_slot(2)

      expect(unit.reload).to be_bye
      expect(final.reload.public_send(:"team_#{child_slot}_id")).to eq survivor.id
    end

    # The gap #bye_occupant_changed? cannot see at all: no team id changes, so
    # the callback never runs, and without refresh_child_slot_from_bye the
    # child keeps a team whose unit is no longer a bye.
    it "clears the child slot even when the move changes no team id" do
      round_one = build_bracket(3)
      bye = round_one.detect(&:bye?)
      final = category.bracket_encounters.find_by(round: 2)
      child_slot = (final.parent_encounter_1_id == bye.id) ? 1 : 2
      empty_slot = (bye.bye_slot == 1) ? 2 : 1

      bye.assign_slot_entry(empty_slot, BracketEntry.for(pool_number: 9, pool_rank: 1, competitor: nil))

      expect(final.reload.public_send(:"team_#{child_slot}_id")).to be_nil
    end
  end
end
