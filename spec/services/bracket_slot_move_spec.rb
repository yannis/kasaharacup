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

      # The drag client cannot express this through the "Move to…" select — it
      # leaves a unit's own slots out — but a grip dropped on the row below it
      # can, and on an Encounter the first write puts one team id into BOTH
      # columns, which #teams_differ rejects as an ActiveRecord::RecordInvalid
      # the controller does not rescue. The refusal is what keeps it a 422.
      it "rejects a move between the two slots of one unit" do
        build_bracket(pools: 2)
        unit = round_one.first

        expect { described_class.new(category).place(target: ref(unit, 2), source: ref(unit, 1)) }
          .to raise_error(described_class::InvalidMove, /already in this/)
        expect(unit.reload.slot_entry(1)).to be_present
        expect(unit.slot_entry(2)).to be_present
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

    describe "#place into an empty slot" do
      it "moves the entry and leaves the source unit a bye" do
        build_bracket(pools: 2)
        first, second = round_one
        first.clear_slot(2)
        moving = second.slot_entry(1)

        described_class.new(category).place(target: ref(first, 2), source: ref(second, 1))

        expect(first.reload.slot_entry(2).key).to eq moving.key
        expect(second.reload).to be_bye
      end

      it "stops the unit being a bye" do
        build_bracket(pools: 3)
        bye = round_one.detect(&:bye?)
        other = round_one.detect { |record| !record.bye? }
        empty_slot = (bye.bye_slot == 1) ? 2 : 1

        described_class.new(category).place(target: ref(bye, empty_slot), source: ref(other, 1))

        expect(bye.reload).not_to be_bye
      end
    end

    describe "#remove" do
      it "empties the slot and leaves the partner with a bye" do
        build_bracket(pools: 2)
        unit = round_one.first
        survivor = unit.slot_entry(2)

        described_class.new(category).remove(target: ref(unit, 1))

        unit.reload
        expect(unit.slot_entry(1)).to be_nil
        expect(unit).to be_bye
        expect(unit.slot_entry(unit.bye_slot).key).to eq survivor.key
      end

      it "refuses to empty the last entry of a unit" do
        build_bracket(pools: 3)
        bye = round_one.detect(&:bye?)

        expect { described_class.new(category).remove(target: ref(bye, bye.bye_slot)) }
          .to raise_error(described_class::InvalidMove, /nobody in it/)
      end

      it "refuses to empty a slot that is already empty" do
        build_bracket(pools: 3)
        bye = round_one.detect(&:bye?)
        empty_slot = (bye.bye_slot == 1) ? 2 : 1

        expect { described_class.new(category).remove(target: ref(bye, empty_slot)) }
          .to raise_error(described_class::InvalidMove, /already empty/)
      end
    end

    describe "the empty-unit refusal" do
      it "refuses to move a bye's only entry into another slot" do
        build_bracket(pools: 3)
        bye = round_one.detect(&:bye?)
        other = round_one.detect { |record| !record.bye? }
        other.clear_slot(2)

        expect {
          described_class.new(category).place(target: ref(other, 2), source: ref(bye, bye.bye_slot))
        }.to raise_error(described_class::InvalidMove, /nobody in it/)
      end

      # A SWAP hands the source unit the displaced entry, so its count is
      # unchanged and a bye may still take part in one. Without this
      # distinction the empty-unit rule would make every bye immovable.
      it "allows a bye's entry to be swapped with an occupied slot" do
        build_bracket(pools: 3)
        bye = round_one.detect(&:bye?)
        other = round_one.detect { |record| !record.bye? }

        expect {
          described_class.new(category).place(target: ref(other, 1), source: ref(bye, bye.bye_slot))
        }.not_to raise_error
        expect(bye.reload).to be_bye
      end
    end

    describe "#place from the waiting area" do
      it "places a waiting entry into an empty slot" do
        build_bracket(pools: 2)
        unit = round_one.first
        pulled = unit.slot_entry(2)
        unit.clear_slot(2)

        described_class.new(category).place(target: ref(unit, 2), entry_key: pulled.key)

        expect(unit.reload.slot_entry(2).key).to eq pulled.key
        expect(BracketWaitingEntries.for(category)).to be_empty
      end

      it "displaces the occupant back into the waiting area" do
        build_bracket(pools: 2)
        first, second = round_one
        pulled = first.slot_entry(1)
        first.clear_slot(1)
        displaced = second.slot_entry(1)

        described_class.new(category).place(target: ref(second, 1), entry_key: pulled.key)

        expect(second.reload.slot_entry(1).key).to eq pulled.key
        expect(BracketWaitingEntries.for(category).map(&:key)).to eq [displaced.key]
      end

      # THE refusal the waiting area needs and the swap tool never did. A swap
      # exchanges two occupants, so nothing can be duplicated; a placement has
      # no source row for an expectation hint to describe, and nothing in the
      # schema objects — Encounter#teams_differ compares one row's two slots and
      # no more. Two admins on the same waiting row, or one admin on a stale
      # tree, would write 3.2 into two slots and the next Update bracket would
      # resolve the same competitor into both.
      it "refuses to place an entry that already occupies a slot" do
        build_bracket(pools: 2)
        first, second = round_one
        first.clear_slot(1) # make room, so the refusal is about the DUPLICATE
        placed = second.slot_entry(1)

        expect { described_class.new(category).place(target: ref(first, 1), entry_key: placed.key) }
          .to raise_error(described_class::InvalidMove, /not waiting to be placed/)
      end

      it "refuses an entry key nothing in the category answers to" do
        build_bracket(pools: 2)
        unit = round_one.first
        unit.clear_slot(1)

        expect { described_class.new(category).place(target: ref(unit, 1), entry_key: "42.7") }
          .to raise_error(described_class::InvalidMove, /not waiting to be placed/)
      end

      it "honours an empty expectation hint on the target" do
        build_bracket(pools: 2)
        first, second = round_one
        pulled = first.slot_entry(1)
        first.clear_slot(1)

        # The client drew a tree in which second's slot 1 was EMPTY. It is not.
        expect {
          described_class.new(category)
            .place(target: ref(second, 1), entry_key: pulled.key, expected_entry: "")
        }.to raise_error(described_class::InvalidMove, /reload and try again/)
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

  describe ".eligibility" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }

    def build_bracket(pools)
      (1..pools).each do |pool|
        (1..2).each { |rank| create(:team, team_category: category, pool_number: pool, pool_rank: rank) }
      end
      TeamCategoryBracketBuilder.new(category).call
      described_class.bracket_for(category.reload)
    end

    it "offers both slots of an untouched unit as source and target" do
      records = build_bracket(2)
      unit = records.detect { |record| record.round == 1 }

      eligibility = described_class.eligibility(records)

      expect(eligibility.sources).to include([unit.id, 1], [unit.id, 2])
      expect(eligibility.targets).to include([unit.id, 1], [unit.id, 2])
    end

    # The distinction the single swappable_slots set could not express, and the
    # reason the tree never offered an empty slot at all.
    it "offers a bye's empty side as a target but never as a source" do
      records = build_bracket(3)
      bye = records.detect { |record| record.round == 1 && record.bye? }
      empty_slot = (bye.bye_slot == 1) ? 2 : 1

      eligibility = described_class.eligibility(records)

      expect(eligibility.targets).to include([bye.id, empty_slot])
      expect(eligibility.sources).not_to include([bye.id, empty_slot])
    end

    it "offers nothing on a unit whose child is scored" do
      build_bracket(3)
      bye = category.bracket_encounters.where(round: 1).detect(&:bye?)
      # The bye's OWN child: it is the node a move of this bye would rewrite,
      # and scoring it is what puts the bye out of reach.
      child = bye.children.first
      child.update!(winner: child.team_1 || child.team_2)

      eligibility = described_class.eligibility(described_class.bracket_for(category.reload))

      expect(eligibility.sources).not_to include([bye.id, bye.bye_slot])
    end

    it "offers nothing outside round 1" do
      records = build_bracket(2)
      final = records.detect { |record| record.round == 2 }

      eligibility = described_class.eligibility(records)

      expect(eligibility.targets.map(&:first)).not_to include final.id
    end
  end

  # What makes the duplicate refusal correct when two admins race: the waiting
  # set is derived from rows this transaction already HOLDS, so the second
  # placement cannot read a snapshot taken before the first one landed.
  #
  # Asserted as an ordering rather than with two threads: the suite runs on
  # use_transactional_fixtures, so a second connection would not see this
  # example's bracket at all and the test would pass for the wrong reason.
  describe "the lock that the duplicate refusal rests on" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }

    it "locks the whole of round 1 before deriving the waiting set" do
      (1..2).each do |pool|
        (1..2).each { |rank| create(:team, team_category: category, pool_number: pool, pool_rank: rank) }
      end
      TeamCategoryBracketBuilder.new(category).call
      unit = category.bracket_encounters.where(round: 1).order(:position).first
      pulled = unit.slot_entry(1)
      unit.clear_slot(1)

      queries = []
      collect = ->(*, payload) { queries << payload[:sql] }
      ActiveSupport::Notifications.subscribed(collect, "sql.active_record") do
        described_class.new(category).place(target: "#{unit.id}-1", entry_key: pulled.key)
      end

      lock_at = queries.index { |sql| sql.include?("FOR UPDATE") }
      # The waiting set resolves its competitors through CategoryPoolSlots, so
      # the first read of the teams table is the earliest it can have run.
      derive_at = queries.index { |sql| sql.match?(/SELECT .*FROM "teams"/) }

      expect(lock_at).to be_present
      expect(derive_at).to be_present
      expect(lock_at).to be < derive_at
    end
  end

  def ref(record, slot) = "#{record.id}-#{slot}"
end
