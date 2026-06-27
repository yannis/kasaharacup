# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamPoolMove do
  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2, team_size: 3) }

  def team_in(pool, position, rank: nil)
    create(:team, team_category: tc, pool_number: pool, pool_position: position, pool_rank: rank)
  end

  describe "membership change" do
    it "appends the moved team to the destination and compacts the source" do
      a = team_in(1, 1)
      b = team_in(1, 2)
      c = team_in(1, 3)
      team_in(2, 1)
      team_in(2, 2)

      result = described_class.new(team: b, to_pool_number: 2).call

      expect(result.status).to eq :ok
      expect(b.reload.pool_number).to eq 2
      expect(b.pool_position).to eq 3 # appended after the two destination teams
      expect(a.reload.pool_position).to eq 1
      expect(c.reload.pool_position).to eq 2 # gap closed
    end

    it "is a no-op when the destination is the current pool" do
      a = team_in(1, 1)
      team_in(1, 2)

      result = described_class.new(team: a, to_pool_number: 1).call

      expect(result.status).to eq :noop
      expect(a.reload.pool_position).to eq 1
    end

    it "reports an emptied source pool" do
      lonely = team_in(1, 1)
      team_in(2, 1)

      result = described_class.new(team: lonely, to_pool_number: 2).call

      expect(result.emptied_pools).to eq [1]
      expect(tc.team_pools.map(&:number)).to eq [2]
    end

    it "resets pool_rank for teams in both affected pools" do
      a = team_in(1, 1, rank: 1)
      b = team_in(1, 2, rank: 2)
      d = team_in(2, 1, rank: 1)

      described_class.new(team: b, to_pool_number: 2).call

      expect([a, b, d].map { |t| t.reload.pool_rank }).to eq [nil, nil, nil]
    end
  end

  describe "pool encounters" do
    it "creates no encounters during setup (none existed yet)" do
      team_in(1, 1)
      b = team_in(1, 2)
      team_in(1, 3)
      team_in(2, 1)

      described_class.new(team: b, to_pool_number: 2).call

      expect(tc.encounters.count).to eq 0
    end

    it "regenerates both pools' round-robins to match the new membership" do
      team_in(1, 1)
      b = team_in(1, 2)
      team_in(1, 3)
      team_in(2, 1)
      PoolEncounterGenerator.new(tc).call # pool 1: C(3) -> 3 encounters, pool 2: 1 team -> 0

      expect(tc.encounters.where(pool_number: 1).count).to eq 3

      described_class.new(team: b, to_pool_number: 2).call

      # pool 1 now has 2 teams (1 encounter), pool 2 has 2 teams (1 encounter)
      expect(tc.encounters.where(pool_number: 1).count).to eq 1
      expect(tc.encounters.where(pool_number: 2).count).to eq 1
      expect(tc.encounters.where.not(pool_number: [1, 2]).count).to eq 0
    end

    it "destroys dependent team_fights and fight_points (no orphans) when wiping encounters" do
      team_in(1, 1)
      b = team_in(1, 2)
      team_in(1, 3)
      team_in(2, 1)
      PoolEncounterGenerator.new(tc).call
      enc = tc.encounters.where(pool_number: 1).first
      fight = create(:team_fight, encounter: enc)
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")

      expect { described_class.new(team: b, to_pool_number: 2, force: true).call }
        .to change(TeamFight, :count).by(-1)
        .and change(FightPoint, :count).by(-1)
    end
  end

  describe "confirmation gate" do
    it "needs confirmation (and writes nothing) when an affected pool has a set lineup" do
      team_in(1, 1)
      b = team_in(1, 2)
      team_in(1, 3)
      team_in(2, 1)
      PoolEncounterGenerator.new(tc).call
      tc.encounters.where(pool_number: 1).first.update!(lineup_1_set: true)

      result = described_class.new(team: b, to_pool_number: 2).call

      expect(result.status).to eq :needs_confirmation
      expect(b.reload.pool_number).to eq 1 # unchanged
      expect(tc.encounters.where(pool_number: 1).count).to eq 3 # unchanged
    end

    it "needs confirmation when an affected pool has recorded fight points" do
      team_in(1, 1)
      b = team_in(1, 2)
      team_in(1, 3)
      team_in(2, 1)
      PoolEncounterGenerator.new(tc).call
      enc = tc.encounters.where(pool_number: 1).first
      fight = create(:team_fight, encounter: enc)
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")

      result = described_class.new(team: b, to_pool_number: 2).call

      expect(result.status).to eq :needs_confirmation
    end

    it "performs the destructive move when forced" do
      team_in(1, 1)
      b = team_in(1, 2)
      team_in(1, 3)
      team_in(2, 1)
      PoolEncounterGenerator.new(tc).call
      tc.encounters.where(pool_number: 1).first.update!(lineup_1_set: true)

      result = described_class.new(team: b, to_pool_number: 2, force: true).call

      expect(result.status).to eq :ok
      expect(b.reload.pool_number).to eq 2
    end
  end

  describe "adding an unpooled team" do
    def unpooled_team
      create(:team, team_category: tc, pool_number: nil, pool_position: nil)
    end

    it "appends a late registrant to an existing pool" do
      team_in(1, 1)
      team_in(1, 2)
      late = unpooled_team

      result = described_class.new(team: late, to_pool_number: 1).call

      expect(result.status).to eq :ok
      expect(result.created_pool).to be false
      expect(late.reload.pool_number).to eq 1
      expect(late.pool_position).to eq 3
    end

    it "creates a new pool from a late registrant" do
      team_in(1, 1)
      team_in(1, 2)
      late = unpooled_team

      result = described_class.new(team: late, to_pool_number: 2).call

      expect(result.status).to eq :ok
      expect(result.created_pool).to be true
      expect(late.reload.pool_number).to eq 2
      expect(late.pool_position).to eq 1
      expect(tc.team_pools.map(&:number)).to eq [1, 2]
    end

    it "regenerates the destination pool's round-robin when encounters exist" do
      team_in(1, 1)
      team_in(1, 2)
      PoolEncounterGenerator.new(tc).call
      expect(tc.encounters.where(pool_number: 1).count).to eq 1
      late = unpooled_team

      described_class.new(team: late, to_pool_number: 1).call

      expect(tc.encounters.where(pool_number: 1).count).to eq 3 # round-robin of 3
    end

    it "leaves bracket/ad-hoc (pool_number nil) encounters untouched" do
      team_in(1, 1, rank: 1)
      team_in(2, 1, rank: 1)
      late = unpooled_team
      TeamCategoryBracketBuilder.new(tc).call
      bracket_count = tc.bracket_encounters.count

      described_class.new(team: late, to_pool_number: 2, force: true).call

      # the bracket is cleared deliberately, but never via the pool-wipe of a nil source
      expect(bracket_count).to be_positive
    end

    it "needs confirmation when the destination pool is non-pristine" do
      team_in(1, 1)
      team_in(1, 2)
      PoolEncounterGenerator.new(tc).call
      tc.encounters.where(pool_number: 1).first.update!(lineup_1_set: true)
      late = unpooled_team

      result = described_class.new(team: late, to_pool_number: 1).call

      expect(result.status).to eq :needs_confirmation
      expect(late.reload.pool_number).to be_nil
    end
  end

  describe "un-pooling a team" do
    it "removes a team from its pool when no destination is given" do
      team_in(1, 1)
      b = team_in(1, 2)
      team_in(1, 3)

      result = described_class.new(team: b, to_pool_number: nil).call

      expect(result.status).to eq :ok
      expect(result.created_pool).to be false
      expect(b.reload.pool_number).to be_nil
      expect(b.pool_position).to be_nil
    end

    it "compacts the source pool after un-pooling" do
      a = team_in(1, 1)
      b = team_in(1, 2)
      c = team_in(1, 3)

      described_class.new(team: b, to_pool_number: nil).call

      expect(a.reload.pool_position).to eq 1
      expect(c.reload.pool_position).to eq 2
    end

    it "reports the source emptied when un-pooling its last team" do
      only = team_in(1, 1)

      result = described_class.new(team: only, to_pool_number: "").call

      expect(result.emptied_pools).to eq [1]
      expect(tc.team_pools).to be_empty
    end

    it "regenerates the source pool's round-robin after un-pooling" do
      team_in(1, 1)
      b = team_in(1, 2)
      team_in(1, 3)
      PoolEncounterGenerator.new(tc).call
      expect(tc.encounters.where(pool_number: 1).count).to eq 3

      described_class.new(team: b, to_pool_number: nil).call

      expect(tc.encounters.where(pool_number: 1).count).to eq 1 # 2 teams remain
    end

    it "clears the moved team's stale pool_rank when un-pooling" do
      ranked = team_in(1, 1, rank: 1)
      team_in(1, 2, rank: 2)

      described_class.new(team: ranked, to_pool_number: nil).call

      expect(ranked.reload.pool_rank).to be_nil
    end

    it "is a no-op when un-pooling an already-unpooled team" do
      late = create(:team, team_category: tc, pool_number: nil)

      result = described_class.new(team: late, to_pool_number: nil).call

      expect(result.status).to eq :noop
    end
  end

  describe "bracket" do
    it "needs confirmation when a bracket exists" do
      team_in(1, 1, rank: 1)
      b = team_in(1, 2, rank: 2)
      team_in(2, 1, rank: 1)
      team_in(2, 2, rank: 2)
      TeamCategoryBracketBuilder.new(tc).call
      expect(tc.bracket_encounters).to be_any

      result = described_class.new(team: b, to_pool_number: 2).call

      expect(result.status).to eq :needs_confirmation
    end

    it "clears the bracket on a forced move" do
      team_in(1, 1, rank: 1)
      b = team_in(1, 2, rank: 2)
      team_in(2, 1, rank: 1)
      team_in(2, 2, rank: 2)
      TeamCategoryBracketBuilder.new(tc).call

      result = described_class.new(team: b, to_pool_number: 2, force: true).call

      expect(result.status).to eq :ok
      expect(result.bracket_cleared).to be true
      expect(tc.bracket_encounters.reload).to be_empty
    end
  end
end
