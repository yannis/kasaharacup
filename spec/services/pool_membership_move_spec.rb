# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolMembershipMove do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }

  def member_in(pool, position, rank: nil)
    kenshi = create(:kenshi, cup: cup)
    create(:participation, category: category, kenshi: kenshi,
      pool_number: pool, pool_position: position, pool_rank: rank)
  end

  def unpooled_member
    create(:participation, category: category,
      kenshi: create(:kenshi, cup: cup), pool_number: nil, pool_position: nil)
  end

  describe "membership change" do
    it "appends the moved member to the destination and compacts the source" do
      a = member_in(1, 1)
      b = member_in(1, 2)
      c = member_in(1, 3)
      member_in(2, 1)
      member_in(2, 2)

      result = described_class.new(participation: b, to_pool_number: 2).call

      expect(result.status).to eq :ok
      expect(b.reload.pool_number).to eq 2
      expect(b.pool_position).to eq 3
      expect(a.reload.pool_position).to eq 1
      expect(c.reload.pool_position).to eq 2
    end

    it "is a no-op when the destination is the current pool" do
      a = member_in(1, 1)
      member_in(1, 2)

      result = described_class.new(participation: a, to_pool_number: 1).call

      expect(result.status).to eq :noop
      expect(a.reload.pool_position).to eq 1
    end

    it "reports an emptied source pool" do
      lonely = member_in(1, 1)
      member_in(2, 1)

      result = described_class.new(participation: lonely, to_pool_number: 2).call

      expect(result.emptied_pools).to eq [1]
      expect(category.pools.map(&:number)).to eq [2]
    end

    it "resets pool_rank for members in both affected pools" do
      a = member_in(1, 1, rank: 1)
      b = member_in(1, 2, rank: 2)
      d = member_in(2, 1, rank: 1)

      described_class.new(participation: b, to_pool_number: 2).call

      expect([a, b, d].map { |p| p.reload.pool_rank }).to eq [nil, nil, nil]
    end
  end

  describe "pool fights" do
    it "creates no fights during setup (none existed yet)" do
      member_in(1, 1)
      b = member_in(1, 2)
      member_in(1, 3)
      member_in(2, 1)

      described_class.new(participation: b, to_pool_number: 2).call

      expect(category.pool_fights.count).to eq 0
    end

    it "regenerates both pools' cyclic fights to match the new membership" do
      member_in(1, 1)
      b = member_in(1, 2)
      member_in(1, 3)
      member_in(2, 1)
      PoolFightGenerator.new(category).call

      expect(category.pool_fights.where(pool_number: 1).count).to eq 3

      described_class.new(participation: b, to_pool_number: 2).call

      expect(category.pool_fights.where(pool_number: 1).count).to eq 1
      expect(category.pool_fights.where(pool_number: 2).count).to eq 1
    end

    it "destroys dependent fight_points (no orphans) when wiping fights" do
      member_in(1, 1)
      b = member_in(1, 2)
      member_in(1, 3)
      member_in(2, 1)
      PoolFightGenerator.new(category).call
      fight = category.pool_fights.where(pool_number: 1).first
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")

      expect { described_class.new(participation: b, to_pool_number: 2, force: true).call }
        .to change(FightPoint, :count).by(-1)
    end
  end

  describe "confirmation gate" do
    it "needs confirmation (and writes nothing) when an affected pool has a recorded result" do
      member_in(1, 1)
      b = member_in(1, 2)
      member_in(1, 3)
      member_in(2, 1)
      PoolFightGenerator.new(category).call
      category.pool_fights.where(pool_number: 1).first.update_column(:draw, true)

      result = described_class.new(participation: b, to_pool_number: 2).call

      expect(result.status).to eq :needs_confirmation
      expect(b.reload.pool_number).to eq 1
      expect(category.pool_fights.where(pool_number: 1).count).to eq 3
    end

    it "performs the destructive move when forced" do
      member_in(1, 1)
      b = member_in(1, 2)
      member_in(1, 3)
      member_in(2, 1)
      PoolFightGenerator.new(category).call
      category.pool_fights.where(pool_number: 1).first.update_column(:draw, true)

      result = described_class.new(participation: b, to_pool_number: 2, force: true).call

      expect(result.status).to eq :ok
      expect(b.reload.pool_number).to eq 2
    end
  end

  describe "adding an unpooled member" do
    it "appends a late registrant to an existing pool" do
      member_in(1, 1)
      member_in(1, 2)
      late = unpooled_member

      result = described_class.new(participation: late, to_pool_number: 1).call

      expect(result.status).to eq :ok
      expect(result.created_pool).to be false
      expect(late.reload.pool_number).to eq 1
      expect(late.pool_position).to eq 3
    end

    it "creates a new pool from a late registrant" do
      member_in(1, 1)
      member_in(1, 2)
      late = unpooled_member

      result = described_class.new(participation: late, to_pool_number: 2).call

      expect(result.status).to eq :ok
      expect(result.created_pool).to be true
      expect(late.reload.pool_number).to eq 2
      expect(late.pool_position).to eq 1
      expect(category.pools.map(&:number)).to eq [1, 2]
    end
  end

  describe "un-pooling a member" do
    it "removes a member from its pool when no destination is given" do
      member_in(1, 1)
      b = member_in(1, 2)
      member_in(1, 3)

      result = described_class.new(participation: b, to_pool_number: nil).call

      expect(result.status).to eq :ok
      expect(b.reload.pool_number).to be_nil
      expect(b.pool_position).to be_nil
    end

    it "compacts the source pool after un-pooling" do
      a = member_in(1, 1)
      b = member_in(1, 2)
      c = member_in(1, 3)

      described_class.new(participation: b, to_pool_number: nil).call

      expect(a.reload.pool_position).to eq 1
      expect(c.reload.pool_position).to eq 2
    end

    it "clears the moved member's stale pool_rank when un-pooling" do
      ranked = member_in(1, 1, rank: 1)
      member_in(1, 2, rank: 2)

      described_class.new(participation: ranked, to_pool_number: nil).call

      expect(ranked.reload.pool_rank).to be_nil
    end

    it "is a no-op when un-pooling an already-unpooled member" do
      late = unpooled_member

      result = described_class.new(participation: late, to_pool_number: nil).call

      expect(result.status).to eq :noop
    end
  end

  describe "bracket" do
    it "needs confirmation when a bracket exists" do
      member_in(1, 1, rank: 1)
      member_in(1, 2, rank: 2)
      b = member_in(1, 3, rank: 3)
      member_in(2, 1, rank: 1)
      member_in(2, 2, rank: 2)
      IndividualCategoryBracketBuilder.new(category).call
      expect(category.bracket_fights).to be_any

      result = described_class.new(participation: b, to_pool_number: 2).call

      expect(result.status).to eq :needs_confirmation
    end

    it "clears the bracket on a forced move" do
      member_in(1, 1, rank: 1)
      member_in(1, 2, rank: 2)
      b = member_in(1, 3, rank: 3)
      member_in(2, 1, rank: 1)
      member_in(2, 2, rank: 2)
      IndividualCategoryBracketBuilder.new(category).call

      result = described_class.new(participation: b, to_pool_number: 2, force: true).call

      expect(result.status).to eq :ok
      expect(result.bracket_cleared).to be true
      expect(category.bracket_fights.reload).to be_empty
    end
  end
end
