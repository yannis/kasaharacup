# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketSlotMove do
  let(:cup) { create(:cup) }

  # Every example runs against BOTH record types. That is the whole reason
  # BracketSlots exists, and a spec that only exercised Encounter would let the
  # two drift while looking shared on paper.
  shared_examples "a bracket slot move" do
    describe "#place with a source slot" do
      it "exchanges the entries of two round-1 slots" do
        build_bracket(pools: 2)
        first, second = round_one
        moving_in = second.slot_entry(1)
        moving_out = first.slot_entry(1)

        described_class.new(category).place(target: ref(first, 1), source: ref(second, 1))

        expect(first.reload.slot_entry(1).key).to eq moving_in.key
        expect(second.reload.slot_entry(1).key).to eq moving_out.key
      end

      # The point of the feature. EncounterTeamSwap wrote team_N_id alone and
      # refused a pool-seeded slot outright, because the next build re-resolved
      # the descriptor it left behind and undid the swap.
      it "carries the pool descriptor with the entry" do
        build_bracket(pools: 2)
        first, second = round_one
        moving_in = second.slot_entry(1)

        described_class.new(category).place(target: ref(first, 1), source: ref(second, 1))

        expect(first.reload.slot_entry(1))
          .to have_attributes(pool_number: moving_in.pool_number, pool_rank: moving_in.pool_rank)
      end

      it "rejects a slot outside round 1" do
        build_bracket(pools: 2)
        final = category.bracket_records.find_by(round: 2)

        expect { described_class.new(category).place(target: ref(final, 1), source: ref(round_one.first, 1)) }
          .to raise_error(described_class::InvalidMove, /only round-1 slots/)
      end

      it "rejects a move onto itself" do
        build_bracket(pools: 2)
        unit = round_one.first

        expect { described_class.new(category).place(target: ref(unit, 1), source: ref(unit, 1)) }
          .to raise_error(described_class::InvalidMove, /already in this slot/)
      end

      it "rejects a move when an impacted record is scored" do
        build_bracket(pools: 2)
        first, second = round_one
        score!(first)

        expect { described_class.new(category).place(target: ref(first, 1), source: ref(second, 1)) }
          .to raise_error(described_class::InvalidMove, /already has recorded results/)
      end
    end

    describe "expectation hints" do
      it "refuses when the target no longer holds what the client drew" do
        build_bracket(pools: 2)
        first, second = round_one

        expect {
          described_class.new(category)
            .place(target: ref(first, 1), source: ref(second, 1), expected_entry: "9.9")
        }.to raise_error(described_class::InvalidMove, /reload and try again/)
      end

      it "refuses when the source no longer holds what the client drew" do
        build_bracket(pools: 2)
        first, second = round_one

        expect {
          described_class.new(category)
            .place(target: ref(first, 1), source: ref(second, 1), expected_source_entry: "9.9")
        }.to raise_error(described_class::InvalidMove, /reload and try again/)
      end

      it "accepts a hint that matches" do
        build_bracket(pools: 2)
        first, second = round_one

        expect {
          described_class.new(category).place(
            target: ref(first, 1), source: ref(second, 1),
            expected_entry: first.slot_entry(1).key,
            expected_source_entry: second.slot_entry(1).key
          )
        }.not_to raise_error
      end
    end

    describe "a bye" do
      it "re-seeds the child slot when a bye's occupant is swapped out" do
        build_bracket(pools: 3)
        bye = round_one.detect(&:bye?)
        other = round_one.detect { |record| !record.bye? }
        moving_in = other.slot_entry(1)

        described_class.new(category).place(target: ref(bye, bye.bye_slot), source: ref(other, 1))

        expect(bye.reload.slot_entry(bye.bye_slot).key).to eq moving_in.key
      end
    end
  end

  context "on a team category" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2, team_size: 3) }

    def build_bracket(pools:)
      (1..pools).each do |pool|
        (1..2).each { |rank| create(:team, team_category: category, pool_number: pool, pool_rank: rank) }
      end
      TeamCategoryBracketBuilder.new(category).call
    end

    def round_one
      category.bracket_encounters.where(round: 1).order(:position).to_a
    end

    def score!(record)
      record.update!(winner: record.team_1 || record.team_2)
    end

    it_behaves_like "a bracket slot move"

    # An Encounter forward-propagates a bye's occupant into its child slot, so
    # exchanging the occupants of two byes that feed ONE round-2 node writes a
    # team into a child whose other slot still holds it — teams_differ rejects
    # it and the RecordInvalid escapes the caller's rescue as a 500. Built by
    # hand rather than hunted for in a field size, so it cannot silently stop
    # being covered when the draw changes.
    it "refuses to exchange two byes that feed the same round-2 node" do
      build_bracket(pools: 4)
      first, second = round_one
      final = category.bracket_encounters
        .where(round: 2).detect { |node|
        [node.parent_encounter_1_id,
          node.parent_encounter_2_id].sort == [first.id, second.id].sort
      }
      expect(final).to be_present

      first.clear_slot(2)
      second.clear_slot(2)
      expect(first.reload).to be_bye
      expect(second.reload).to be_bye

      expect {
        described_class.new(category).place(target: ref(first, first.bye_slot), source: ref(second, second.bye_slot))
      }.to raise_error(described_class::InvalidMove, /already meet in round 2/)
    end
  end

  context "on an individual category" do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }

    def build_bracket(pools:)
      (1..pools).each do |pool|
        (1..2).each do |rank|
          create(:participation, category: category, pool_number: pool, pool_position: rank, pool_rank: rank)
        end
      end
      IndividualCategoryBracketBuilder.new(category).call
    end

    def round_one
      category.bracket_fights.where(round: 1).order(:position).to_a
    end

    def score!(record)
      record.update!(winner: record.fighter_1 || record.fighter_2, fighter_type: "Kenshi")
    end

    it_behaves_like "a bracket slot move"

    # The counterpart of the team example above, asserting the OPPOSITE. A child
    # fight resolves its fighters lazily through parent_fight_N&.winner_or_bye,
    # so nothing is written into it and there is nothing to collide — refusing
    # here would cost the admin a legal move and point them at a rebuild they
    # do not need.
    it "allows two byes that feed the same round-2 node to be exchanged" do
      build_bracket(pools: 4)
      first, second = round_one
      first.clear_slot(2)
      second.clear_slot(2)
      moving_in = second.reload.slot_entry(second.bye_slot)

      expect {
        described_class.new(category).place(target: ref(first, first.reload.bye_slot),
          source: ref(second, second.bye_slot))
      }.not_to raise_error
      expect(first.reload.slot_entry(first.bye_slot).key).to eq moving_in.key
    end
  end

  def ref(record, slot) = "#{record.id}-#{slot}"
end
