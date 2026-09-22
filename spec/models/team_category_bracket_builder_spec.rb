# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamCategoryBracketBuilder do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }

  def ranked_team(pool_number:, pool_rank:)
    create(:team, team_category: category, pool_number: pool_number, pool_rank: pool_rank)
  end

  context "with 2 pools × 2 ranks" do
    let!(:t1_1) { ranked_team(pool_number: 1, pool_rank: 1) }
    let!(:t1_2) { ranked_team(pool_number: 1, pool_rank: 2) }
    let!(:t2_1) { ranked_team(pool_number: 2, pool_rank: 1) }
    let!(:t2_2) { ranked_team(pool_number: 2, pool_rank: 2) }

    it "creates a 4-team bracket: 2 first-round encounters + 1 final" do
      encounters = described_class.new(category).call

      expect(encounters.count { |e| e.round == 1 }).to eq 2
      expect(encounters.count { |e| e.round == 2 }).to eq 1
    end

    it "splits each pool's rank-1 and rank-2 across the two first-round encounters" do
      described_class.new(category).call
      round_one = category.bracket_encounters.where(round: 1).order(:position)

      round_one.each do |enc|
        pools = [enc.team_1.pool_number, enc.team_2.pool_number]
        expect(pools.uniq.size).to eq 2 # a two-pool field draws 1.1 v 2.2 / 1.2 v 2.1
      end
    end

    it "wires the final to both first-round encounters" do
      described_class.new(category).call
      round_one = category.bracket_encounters.where(round: 1).order(:position).to_a
      final = category.bracket_encounters.find_by(round: 2)

      expect(final.parent_encounter_1).to eq round_one[0]
      expect(final.parent_encounter_2).to eq round_one[1]
    end
  end

  context "with a bye (3 teams)" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 1) }
    let!(:t1_1) { ranked_team(pool_number: 1, pool_rank: 1) }
    let!(:t2_1) { ranked_team(pool_number: 2, pool_rank: 1) }
    let!(:t3_1) { ranked_team(pool_number: 3, pool_rank: 1) }

    it "seeds the bye team into its round-2 child slot at build time" do
      described_class.new(category).call
      final = category.bracket_encounters.find_by(round: 2)
      bye = category.bracket_encounters.where(round: 1).detect(&:bye?)

      seeded = [final.team_1_id, final.team_2_id]
      expect(seeded).to include(bye.bye_team.id)
    end
  end

  context "idempotency and re-resolve" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 1) }
    let!(:t1_1) { ranked_team(pool_number: 1, pool_rank: 1) }
    let!(:t2_1) { ranked_team(pool_number: 2, pool_rank: 1) }

    it "does not duplicate encounters on a second call" do
      described_class.new(category).call
      expect { described_class.new(category).call }
        .not_to change { category.bracket_encounters.count }
    end

    it "re-resolves a first-round slot through assign_team_to_slot when ranks change" do
      described_class.new(category).call
      enc = category.bracket_encounters.find_by(round: 1, team_1_pool_number: 1)
      replacement = ranked_team(pool_number: 1, pool_rank: 1)
      t1_1.update!(pool_rank: nil)

      described_class.new(category).call

      expect(enc.reload.team_1_id).to eq replacement.id
    end

    it "does not disturb a scored (non-pristine) first-round encounter on a non-force update" do
      described_class.new(category).call
      enc = category.bracket_encounters.find_by(round: 1, team_1_pool_number: 1)
      fight = create(:team_fight, encounter: enc, kenshi_1: create(:kenshi, cup: cup))
      create(:fight_point, scorable: fight, fighter_side: "fighter_1")
      expect(enc.reload.pristine?).to be false
      original_team_1 = enc.team_1_id

      # Ranks change, but a non-force rebuild must preserve in-progress scoring —
      # discarding it is what the explicit "Force rebuild" path is for.
      ranked_team(pool_number: 1, pool_rank: 1)
      t1_1.update!(pool_rank: nil)
      described_class.new(category).call

      expect(enc.reload.team_1_id).to eq original_team_1
      expect(fight.reload.fight_points).to be_present
    end

    # The other half of that rule: an auto-seeded lineup is NOT work in
    # progress. Opening a panel confirms both sides, which used to make the
    # encounter non-pristine — so a rank change after anyone had merely looked
    # at the bracket silently stopped propagating into its slots.
    it "still re-resolves a slot on an encounter whose panel auto-seeded its lineups" do
      described_class.new(category).call
      enc = category.bracket_encounters.find_by(round: 1, team_1_pool_number: 1)
      enc.update!(lineup_1_set: true, lineup_2_set: true)
      replacement = ranked_team(pool_number: 1, pool_rank: 1)
      t1_1.update!(pool_rank: nil)

      described_class.new(category).call

      expect(enc.reload.team_1_id).to eq replacement.id
    end

    it "leaves a slot alone once an admin has ordered its fighters" do
      described_class.new(category).call
      enc = category.bracket_encounters.find_by(round: 1, team_1_pool_number: 1)
      enc.update!(lineup_1_set: true, lineup_1_set_by_admin: true)
      original_team_1 = enc.team_1_id

      ranked_team(pool_number: 1, pool_rank: 1)
      t1_1.update!(pool_rank: nil)
      described_class.new(category).call

      expect(enc.reload.team_1_id).to eq original_team_1
    end
  end

  context "force rebuild of a multi-round bracket" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 1) }

    it "destroys children before parents and rebuilds" do
      4.times { |i| ranked_team(pool_number: i + 1, pool_rank: 1) }
      described_class.new(category).call
      create(:team_fight, encounter: category.bracket_encounters.find_by(round: 1, position: 1))
      original_ids = category.bracket_encounters.pluck(:id)

      rebuilt = described_class.new(category, rebuild_started: true).call

      expect(rebuilt.size).to eq 3
      expect(category.bracket_encounters.pluck(:id)).not_to match_array original_ids
    end
  end

  context "bracket-only category (no pool phase)" do
    let(:category) { create(:team_category, cup: cup, pool_size: nil) }

    it "builds a fully resolved bracket from teams, without pool metadata" do
      teams = create_list(:team, 4, team_category: category)

      encounters = described_class.new(category, random: Random.new(1)).call
      round_one = category.bracket_encounters.where(round: 1).order(:position)

      expect(encounters.count { |e| e.round == 1 }).to eq 2
      expect(encounters.count { |e| e.round == 2 }).to eq 1
      expect(round_one.flat_map { |e| [e.team_1, e.team_2] }).to match_array teams
      metadata = round_one.pluck(:team_1_pool_number, :team_1_pool_rank,
        :team_2_pool_number, :team_2_pool_rank).flatten.uniq
      expect(metadata).to eq [nil]
    end

    it "builds no bracket for 0 or 1 team" do
      expect(described_class.new(category).call).to eq []

      create(:team, team_category: category)
      expect(described_class.new(category).call).to eq []
      expect(category.bracket_encounters).to be_empty
    end

    it "seeds a bye's team into its round-2 slot at build time" do
      create_list(:team, 3, team_category: category)

      described_class.new(category, random: Random.new(1)).call
      bye = category.bracket_encounters.where(round: 1).detect(&:bye?)
      final = category.bracket_encounters.find_by(round: 2)

      expect([final.team_1_id, final.team_2_id]).to include bye.bye_team.id
    end

    it "does not duplicate or reshuffle on a second non-rebuild call" do
      create_list(:team, 4, team_category: category)
      first = described_class.new(category, random: Random.new(1)).call

      second = described_class.new(category, random: Random.new(2)).call

      expect(second.map(&:id)).to eq first.map(&:id)
      expect(second.map(&:team_1_id)).to eq first.map(&:team_1_id)
    end

    it "redraws on rebuild_started: true" do
      create_list(:team, 4, team_category: category)
      described_class.new(category, random: Random.new(1)).call
      original_ids = category.bracket_encounters.pluck(:id)

      described_class.new(category, rebuild_started: true, random: Random.new(2)).call

      expect(category.bracket_encounters.pluck(:id)).not_to match_array original_ids
    end
  end

  describe "a manual layout and a later update" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }

    before do
      (1..2).each do |pool|
        (1..2).each { |rank| ranked_team(pool_number: pool, pool_rank: rank) }
      end
      described_class.new(category).call
    end

    def round_one = category.bracket_encounters.where(round: 1).order(:position).to_a

    def layout = round_one.map { |e| [e.slot_entry(1)&.key, e.slot_entry(2)&.key] }

    # The whole point of moving the descriptor with the entry. Before it, a
    # swapped slot kept its OLD descriptor and the next update re-resolved it —
    # silently undoing the admin's work, which is why pooled categories were
    # refused a swap outright.
    it "keeps the admin's layout" do
      first, second = round_one
      BracketSlotMove.new(category).place(target: "#{first.id}-1", source: "#{second.id}-1")
      after_move = layout

      described_class.new(category.reload).call

      expect(layout).to eq after_move
    end

    it "flows corrected standings into the slot the admin chose" do
      first, second = round_one
      BracketSlotMove.new(category).place(target: "#{first.id}-1", source: "#{second.id}-1")
      moved = first.reload.slot_entry(1)
      # The pool re-ranks: its two qualifiers change places.
      was_here = category.teams.find_by(pool_number: moved.pool_number, pool_rank: moved.pool_rank)
      other_rank = (moved.pool_rank == 1) ? 2 : 1
      now_here = category.teams.find_by(pool_number: moved.pool_number, pool_rank: other_rank)
      was_here.update!(pool_rank: other_rank)
      now_here.update!(pool_rank: moved.pool_rank)

      described_class.new(category.reload).call

      expect(first.reload.slot_entry(1)).to have_attributes(
        pool_number: moved.pool_number, pool_rank: moved.pool_rank, competitor: now_here
      )
    end

    it "leaves an emptied slot empty" do
      first, = round_one
      BracketSlotMove.new(category).remove(target: "#{first.id}-1")

      described_class.new(category.reload).call

      expect(round_one.first.slot_entry(1)).to be_nil
    end
  end
end
