# frozen_string_literal: true

require "rails_helper"

RSpec.describe EncounterTeamSwap do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: nil) }

  def build_bracket(team_count)
    create_list(:team, team_count, team_category: category)
    TeamCategoryBracketBuilder.new(category, random: Random.new(1)).call
  end

  def round_one
    category.bracket_encounters.where(round: 1).order(:position).to_a
  end

  def stock_rosters
    category.teams.each do |team|
      create_list(:kenshi, category.team_size, cup: cup).each do |kenshi|
        create(:participation, category: category, team: team, kenshi: kenshi)
      end
    end
  end

  describe "#swap" do
    it "exchanges the occupants of two round-1 slots" do
      build_bracket(4)
      first, second = round_one
      moving_in = second.team_1
      moving_out = first.team_1

      described_class.new(first).swap(1, moving_in)

      expect(first.reload.team_1).to eq moving_in
      expect(second.reload.team_1).to eq moving_out
    end

    it "re-seeds the round-2 slot when a bye occupant is swapped out" do
      build_bracket(3)
      bye = round_one.detect(&:bye?)
      fight = round_one.detect { |e| !e.bye? }
      final = category.bracket_encounters.find_by(round: 2)
      moving_in = fight.team_1

      described_class.new(bye).swap(bye.bye_slot, moving_in)

      slot = (final.parent_encounter_1_id == bye.id) ? 1 : 2
      expect(final.reload.public_send(:"team_#{slot}_id")).to eq moving_in.id
    end

    it "rejects a team that does not occupy a bracket slot" do
      build_bracket(4)
      newcomer = create(:team, team_category: category)

      expect { described_class.new(round_one.first).swap(1, newcomer) }
        .to raise_error(described_class::InvalidSwap, /exactly one bracket slot/)
    end

    it "rejects a swap within the same encounter" do
      build_bracket(4)
      encounter = round_one.first

      expect { described_class.new(encounter).swap(1, encounter.team_2) }
        .to raise_error(described_class::InvalidSwap, /already in this encounter/)
    end

    it "rejects the team already occupying the slot" do
      build_bracket(4)
      encounter = round_one.first

      expect { described_class.new(encounter).swap(1, encounter.team_1) }
        .to raise_error(described_class::InvalidSwap, /already occupies/)
    end

    it "rejects an empty slot" do
      build_bracket(3)
      bye = round_one.detect(&:bye?)
      empty_slot = (bye.bye_slot == 1) ? 2 : 1

      expect { described_class.new(bye).swap(empty_slot, round_one.detect { |e| !e.bye? }.team_1) }
        .to raise_error(described_class::InvalidSwap, /no team to swap/)
    end

    it "rejects when an involved encounter has a winner" do
      build_bracket(4)
      first, second = round_one
      second.update!(winner: second.team_1)

      expect { described_class.new(first).swap(1, second.team_1) }
        .to raise_error(described_class::InvalidSwap, /recorded results/)
    end

    it "allows a swap when the lineups were only auto-seeded" do
      build_bracket(4)
      first, second = round_one
      moving_in = second.team_1
      # Opening the panel seeds AND confirms both lineups. That is not a result,
      # so it does not make the encounter ineligible — it only asks for
      # confirmation, which force: true supplies.
      first.update!(lineup_1_set: true, lineup_2_set: true)

      described_class.new(first).swap(1, moving_in, force: true)

      expect(first.reload.team_1).to eq moving_in
      expect(first.lineup_1_set?).to be false
    end

    # Regression: #invalidate_slot nils only the swapped side's fighters. On an
    # encounter whose lineups were auto-seeded when the panel was opened, that
    # left the untouched side alone in every bout, which reads as a forfeit —
    # recompute_winner! then handed the incoming team a 3-0 defeat it never
    # fought, and the recorded winner made the slot unswappable for good.
    it "clears a seeded lineup rather than leaving the other side to win by forfeit" do
      build_bracket(4)
      stock_rosters
      first, second = round_one
      EncounterLineupSeeder.new(first).call

      described_class.new(first.reload).swap(1, second.team_1, force: true)

      first.reload
      expect(first.winner).to be_nil
      expect(first).to be_unscored
      expect(first.lineup_1_set?).to be false
      expect(first.lineup_2_set?).to be false
      expect(first.team_fights).to be_empty
    end

    it "rejects when an involved encounter has a scored bout" do
      build_bracket(4)
      first, second = round_one
      fight = create(:team_fight, encounter: second)
      create(:fight_point, scorable: fight, fighter_side: "fighter_1")

      expect { described_class.new(first).swap(1, second.team_1) }
        .to raise_error(described_class::InvalidSwap, /recorded results/)
    end

    it "rejects when a bye-fed round-2 child has recorded fight points" do
      build_bracket(3)
      bye = round_one.detect(&:bye?)
      fight = round_one.detect { |e| !e.bye? }
      final = category.bracket_encounters.find_by(round: 2)
      team_fight = create(:team_fight, encounter: final)
      create(:fight_point, scorable: team_fight, fighter_side: "fighter_1")

      expect { described_class.new(bye).swap(bye.bye_slot, fight.team_1) }
        .to raise_error(described_class::InvalidSwap, /recorded results/)
    end

    it "rejects a swap whose source slot has changed since the page was drawn" do
      build_bracket(4)
      first, second = round_one
      stale_team = first.team_1
      # Someone else swapped this slot in the meantime.
      described_class.new(first).swap(1, second.team_1)

      expect {
        described_class.new(first.reload)
          .swap(1, second.reload.team_2, expected_team_id: stale_team.id)
      }.to raise_error(described_class::InvalidSwap, /reload and try again/)
    end

    it "accepts a swap whose expected source team still matches" do
      build_bracket(4)
      first, second = round_one
      current = first.team_1
      incoming = second.team_1

      described_class.new(first).swap(1, incoming, expected_team_id: current.id)

      expect(first.reload.team_1).to eq incoming
      expect(second.reload.team_1).to eq current
    end

    # recompute_winner! takes its own lock AFTER the write, so counting
    # "FOR UPDATE" alone would pass without any of this. The property that
    # matters is that both rows are locked BEFORE either slot is written.
    it "locks both encounters before writing either slot" do
      build_bracket(4)
      first, second = round_one

      queries = count_queries { described_class.new(first).swap(1, second.team_1) }
      before_first_write = queries.take_while { |sql| !sql.match?(/\AUPDATE /i) }

      expect(before_first_write.grep(/FOR UPDATE/).size).to eq 2
    end

    it "rejects a swap on a round-2 encounter" do
      build_bracket(3)
      final = category.bracket_encounters.find_by(round: 2)
      fight = round_one.detect { |e| !e.bye? }

      expect { described_class.new(final).swap(1, fight.team_1) }
        .to raise_error(described_class::InvalidSwap, /round-1/)
    end

    it "asks for confirmation before discarding a confirmed fighter order" do
      build_bracket(4)
      first, second = round_one
      first.update!(lineup_1_set: true, lineup_2_set: true)

      expect { described_class.new(first).swap(1, second.team_1) }
        .to raise_error(described_class::NeedsConfirmation, /fighter order/)
      expect(first.reload.team_1).not_to eq second.team_1
    end

    it "does not ask for confirmation when no lineup has been confirmed" do
      build_bracket(4)
      first, second = round_one
      moving_in = second.team_1

      expect { described_class.new(first).swap(1, moving_in) }.not_to raise_error
      expect(first.reload.team_1).to eq moving_in
    end

    # Regression: #unscored? read fight points only, so an encounter the admin
    # had decided by marking every bout hikiwake (0-0, no points, no winner)
    # reported as untouched and the swap destroyed those decisions.
    it "rejects when an involved encounter has bouts marked hikiwake" do
      build_bracket(4)
      stock_rosters
      first, second = round_one
      EncounterLineupSeeder.new(second).call
      second.reload.update!(lineup_1_set: true, lineup_2_set: true)
      second.team_fights.reload.each { |fight| fight.update!(draw: true) if fight.hikiwake_eligible? }

      expect { described_class.new(first).swap(1, second.reload.team_1, force: true) }
        .to raise_error(described_class::InvalidSwap, /recorded results/)
      expect(second.reload.team_fights.where(draw: true)).to be_present
    end

    # Regression: both byes propagate into the same round-2 slot, so writing the
    # first one tripped Encounter#teams_differ and raised RecordInvalid — a 500
    # the caller could not act on, since it is not an InvalidSwap.
    it "refuses two byes that already meet in round 2, without raising RecordInvalid" do
      build_bracket(5)
      children = Hash.new { |hash, key| hash[key] = [] }
      round_one.each do |enc|
        enc.children.each { |child| children[child.id] << enc }
      end
      pair = children.values.find { |parents| parents.size == 2 && parents.all?(&:bye?) }
      expect(pair).to be_present
      bye_a, bye_b = pair

      expect { described_class.new(bye_b).swap(bye_b.bye_slot, bye_a.public_send(:"team_#{bye_a.bye_slot}")) }
        .to raise_error(described_class::InvalidSwap, /already meet in round 2/)
    end

    it "refuses a partner encounter that still carries pool seeding metadata" do
      build_bracket(4)
      first, second = round_one
      second.update_columns(team_1_pool_number: 1, team_1_pool_rank: 1)

      expect { described_class.new(first).swap(1, second.team_1) }
        .to raise_error(described_class::InvalidSwap, /pool standings/)
      expect(second.reload.team_1_pool_number).to eq 1
    end

    it "rejects a drop issued from a tree drawn before the team moved" do
      build_bracket(4)
      first, second = round_one
      moving_in = second.team_1

      expect {
        described_class.new(first).swap(1, moving_in, expected_encounter_id: first.id)
      }.to raise_error(described_class::InvalidSwap, /has moved/)
      expect(first.reload.team_1).not_to eq moving_in
    end

    it "locks a bye-fed round-2 child before writing, since the swap wipes it" do
      build_bracket(3)
      bye = round_one.find(&:bye?)
      fight = round_one.detect { |e| !e.bye? }

      queries = count_queries do
        described_class.new(bye).swap(bye.bye_slot, fight.team_1)
      end
      before_first_write = queries.take_while { |sql| !sql.match?(/\AUPDATE /i) }

      # Both round-1 rows plus the child the bye feeds.
      expect(before_first_write.grep(/FOR UPDATE/).size).to eq 3
    end

    it "rejects swaps on pooled categories" do
      pooled = create(:team_category, cup: cup, pool_size: 3, out_of_pool: 1)
      create(:team, team_category: pooled, pool_number: 1, pool_rank: 1)
      create(:team, team_category: pooled, pool_number: 2, pool_rank: 1)
      TeamCategoryBracketBuilder.new(pooled).call
      encounter = pooled.bracket_encounters.find_by(round: 1)

      expect { described_class.new(encounter).swap(1, encounter.team_2) }
        .to raise_error(described_class::InvalidSwap, /bracket-only/)
    end
  end

  describe ".swappable_slots" do
    def preloaded
      list = category.bracket_encounters
        .includes(:team_1, :team_2, team_fights: :fight_points)
        .bracket_order.to_a
      Encounter.preload_parents(list)
      list
    end

    def slots
      described_class.swappable_slots(preloaded, category: category)
    end

    it "offers both slots of every unscored round-1 encounter" do
      build_bracket(4)
      first, second = round_one

      expect(slots).to contain_exactly(
        [first.id, 1], [first.id, 2], [second.id, 1], [second.id, 2]
      )
    end

    it "offers nothing for rounds >= 2" do
      build_bracket(4)
      final = category.bracket_encounters.find_by(round: 2)

      expect(slots.map(&:first)).not_to include final.id
    end

    it "offers nothing in a pooled category" do
      pooled = create(:team_category, cup: cup, pool_size: 3, out_of_pool: 1)
      create(:team, team_category: pooled, pool_number: 1, pool_rank: 1)
      create(:team, team_category: pooled, pool_number: 2, pool_rank: 1)
      TeamCategoryBracketBuilder.new(pooled).call
      list = pooled.bracket_encounters.includes(:team_1, :team_2).bracket_order.to_a
      Encounter.preload_parents(list)

      expect(described_class.swappable_slots(list, category: pooled)).to be_empty
    end

    it "disables BOTH slots of an encounter that has a recorded result" do
      build_bracket(4)
      first, second = round_one
      first.update!(winner: first.team_1)

      expect(slots).to contain_exactly([second.id, 1], [second.id, 2])
    end

    it "keeps offering an encounter whose lineups were only auto-seeded" do
      build_bracket(4)
      first, = round_one
      first.update!(lineup_1_set: true, lineup_2_set: true)

      expect(slots).to include [first.id, 1], [first.id, 2]
    end

    it "disables a bye whose round-2 child already has a result" do
      build_bracket(3)
      bye = round_one.find(&:bye?)
      expect(bye).to be_present
      child = bye.children.first
      child.update!(winner: child.team_1 || child.team_2)

      expect(slots.map(&:first)).not_to include bye.id
    end

    it "offers the occupied slot of an unscored bye, and not its empty one" do
      build_bracket(3)
      bye = round_one.find(&:bye?)
      empty_slot = (bye.bye_slot == 1) ? 2 : 1

      expect(slots).to include [bye.id, bye.bye_slot]
      expect(slots).not_to include [bye.id, empty_slot]
    end

    it "refuses a round-1 encounter that still carries pool seeding metadata" do
      build_bracket(4)
      first, second = round_one
      first.update_columns(team_1_pool_number: 1, team_1_pool_rank: 1)

      expect(slots).to contain_exactly([second.id, 1], [second.id, 2])
    end

    it "answers a whole bracket without a query per encounter" do
      build_bracket(8)
      list = preloaded

      queries = count_queries { described_class.swappable_slots(list, category: category) }

      expect(queries).to be_empty
    end
  end

  describe "#swappable? and #candidates" do
    it "offers occupied unscored round-1 slots and every other occupant" do
      build_bracket(3)
      bye = round_one.detect(&:bye?)
      fight = round_one.detect { |e| !e.bye? }
      swap = described_class.new(bye)

      expect(swap.swappable?(bye.bye_slot)).to be true
      expect(swap.swappable?((bye.bye_slot == 1) ? 2 : 1)).to be false
      expect(swap.candidates).to contain_exactly(fight.team_1, fight.team_2)
    end

    it "does not offer teams whose own encounter could never accept the swap" do
      build_bracket(8)
      first, second, third, fourth = round_one
      second.update!(winner: second.team_1)
      third.update_columns(team_1_pool_number: 1, team_1_pool_rank: 1)

      candidates = described_class.new(first).candidates

      # A scored encounter and a pool-seeded one are both refused by #swap, so
      # offering their occupants was an option that could only ever error.
      expect(candidates).not_to include second.team_1, second.team_2
      expect(candidates).not_to include third.team_1, third.team_2
      expect(candidates).to include fourth.team_1, fourth.team_2
    end

    it "withdraws the offer once results exist" do
      build_bracket(4)
      encounter = round_one.first
      fight = create(:team_fight, encounter: encounter)
      create(:fight_point, scorable: fight, fighter_side: "fighter_1")

      expect(described_class.new(encounter.reload).swappable?(1)).to be false
    end
  end
end
