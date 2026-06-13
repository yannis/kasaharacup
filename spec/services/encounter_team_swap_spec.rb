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

    it "rejects when an involved encounter has a lineup set" do
      build_bracket(4)
      first, second = round_one
      first.update!(lineup_1_set: true)

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

    it "rejects a swap on a round-2 encounter" do
      build_bracket(3)
      final = category.bracket_encounters.find_by(round: 2)
      fight = round_one.detect { |e| !e.bye? }

      expect { described_class.new(final).swap(1, fight.team_1) }
        .to raise_error(described_class::InvalidSwap, /round-1/)
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

  describe "#swappable? and #candidates" do
    it "offers occupied pristine round-1 slots and every other occupant" do
      build_bracket(3)
      bye = round_one.detect(&:bye?)
      fight = round_one.detect { |e| !e.bye? }
      swap = described_class.new(bye)

      expect(swap.swappable?(bye.bye_slot)).to be true
      expect(swap.swappable?((bye.bye_slot == 1) ? 2 : 1)).to be false
      expect(swap.candidates(bye.bye_slot)).to contain_exactly(fight.team_1, fight.team_2)
    end

    it "withdraws the offer once results exist" do
      build_bracket(4)
      encounter = round_one.first
      encounter.update!(lineup_2_set: true)

      expect(described_class.new(encounter).swappable?(1)).to be false
    end
  end
end
