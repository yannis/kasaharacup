# frozen_string_literal: true

require "rails_helper"

RSpec.describe Encounter do
  let(:tc) { create(:team_category) }

  it "is valid with two distinct teams of the category" do
    encounter = build(:encounter, team_category: tc,
      team_1: create(:team, team_category: tc), team_2: create(:team, team_category: tc))
    expect(encounter).to be_valid
  end

  it "rejects the same team on both sides" do
    team = create(:team, team_category: tc)
    encounter = build(:encounter, team_category: tc, team_1: team, team_2: team)
    expect(encounter).not_to be_valid
  end

  it "rejects a team from another category" do
    foreign = create(:team, team_category: create(:team_category))
    encounter = build(:encounter, team_category: tc,
      team_1: create(:team, team_category: tc), team_2: foreign)
    expect(encounter).not_to be_valid
  end

  describe "bracket vs pool team requirements" do
    it "allows a bracket encounter (pool_number nil) with no teams yet" do
      encounter = build(:encounter, team_category: tc, team_1: nil, team_2: nil, pool_number: nil)
      expect(encounter).to be_valid
    end

    it "requires both teams on a pool encounter" do
      encounter = build(:encounter, team_category: tc, team_1: nil, team_2: nil, pool_number: 1)
      expect(encounter).not_to be_valid
      expect(encounter.errors[:team_1]).to be_present
    end
  end

  describe "#recompute_winner!" do
    let(:t1) { create(:team, team_category: tc) }
    let(:t2) { create(:team, team_category: tc) }
    let(:encounter) { create(:encounter, team_category: tc, team_1: t1, team_2: t2) }

    it "persists the winning team derived from its bouts" do
      a = create(:kenshi, cup: tc.cup)
      b = create(:kenshi, cup: tc.cup)
      tf = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b)
      create(:fight_point, scorable: tf, fighter_side: "fighter_1", kind: "men")

      expect(encounter.reload.winner).to eq t1 # set via TeamFight after_update_commit
    end
  end

  describe "resolution and byes" do
    let(:a) { create(:team, team_category: tc) }
    let(:b) { create(:team, team_category: tc) }

    it "resolves a slot from a parent encounter's winner" do
      parent = create(:encounter, team_category: tc, team_1: a, team_2: b, winner: a)
      child = create(:encounter, team_category: tc, team_1: nil, team_2: nil,
        parent_encounter_1: parent)
      expect(child.resolved_team_1).to eq a
    end

    it "treats a one-sided round-1 encounter with no parents as a bye" do
      bye = build(:encounter, team_category: tc, team_1: a, team_2: nil, round: 1, position: 1)
      expect(bye.bye?).to be true
      expect(bye.bye_team).to eq a
      expect(bye.winner_or_bye).to eq a
    end

    it "is not a bye when the empty side still has a parent feeding it" do
      parent = create(:encounter, team_category: tc, team_1: a, team_2: b)
      enc = build(:encounter, team_category: tc, team_1: a, team_2: nil,
        parent_encounter_2: parent, round: 2, position: 1)
      expect(enc.bye?).to be false
    end
  end

  describe "pool standings recompute" do
    let(:pool_tc) { create(:team_category, team_size: 3, pool_size: 3) }
    let(:t1) { create(:team, team_category: pool_tc, pool_number: 1, pool_position: 1) }
    let(:t2) { create(:team, team_category: pool_tc, pool_number: 1, pool_position: 2) }

    it "persists pool_rank for the pool's teams when a pool encounter completes" do
      encounter = create(:encounter, team_category: pool_tc, pool_number: 1, team_1: t1, team_2: t2)
      # Build the bouts directly (no EncounterLineup membership setup needed here).
      fights = (1..3).map do |pos|
        encounter.team_fights.create!(position: pos,
          kenshi_1: create(:kenshi, cup: pool_tc.cup), kenshi_2: create(:kenshi, cup: pool_tc.cup))
      end
      encounter.update!(lineup_1_set: true, lineup_2_set: true)
      # t1 wins two bouts, the third is a hikiwake -> t1 wins the encounter
      create(:fight_point, scorable: fights[0], fighter_side: "fighter_1", kind: "men")
      create(:fight_point, scorable: fights[1], fighter_side: "fighter_1", kind: "men")
      fights[2].update!(draw: true) # draw change fires the post-commit recompute chain

      expect(t1.reload.pool_rank).to eq 1
      expect(t2.reload.pool_rank).to eq 2
    end
  end

  describe "bracket tree broadcast" do
    # broadcast_replace_later_to enqueues a Turbo::Streams::ActionBroadcastJob, so
    # we drive the job and assert on the underlying ActionCable broadcast (mirrors
    # the Fight competition-tree broadcast spec).
    it "broadcasts a tree replace when a bracket encounter's winner changes" do
      a = create(:team, team_category: tc)
      b = create(:team, team_category: tc)
      encounter = create(:encounter, team_category: tc, team_1: a, team_2: b, round: 1, position: 1)
      allow(ActionCable.server).to receive(:broadcast)

      ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
      begin
        encounter.update!(winner: a)
      ensure
        ActiveJob::Base.queue_adapter.perform_enqueued_jobs = false
      end

      expect(ActionCable.server).to have_received(:broadcast).with(
        kind_of(String),
        include("encounter_tree_team_category_#{tc.id}")
      )
    end

    it "does not broadcast the tree for a pool encounter" do
      a = create(:team, team_category: tc)
      b = create(:team, team_category: tc)
      encounter = create(:encounter, team_category: tc, team_1: a, team_2: b, pool_number: 1)
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      encounter.update!(winner: a)

      tree_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job|
        job[:args].to_s.include?("encounter_tree_team_category_")
      }
      expect(tree_jobs).to be_empty
    end
  end

  describe "advancement and invalidation" do
    let(:a) { create(:team, team_category: tc) }
    let(:b) { create(:team, team_category: tc) }
    let(:c) { create(:team, team_category: tc) }

    def member(team)
      k = create(:kenshi, cup: tc.cup)
      create(:participation, category: tc, team: team, kenshi: k)
      k
    end

    it "propagates a winner into the matching child slot" do
      parent = create(:encounter, team_category: tc, team_1: a, team_2: b)
      child = create(:encounter, team_category: tc, team_1: nil, team_2: nil,
        parent_encounter_1: parent)

      parent.update!(winner: a)

      expect(child.reload.team_1_id).to eq a.id
    end

    it "clears stale points on the side when a slot re-resolves to another team" do
      child = create(:encounter, team_category: tc, team_1: a, team_2: c)
      member(a)
      tf = create(:team_fight, encounter: child, kenshi_1: a.kenshis.first, kenshi_2: c.kenshis.first)
      create(:fight_point, scorable: tf, fighter_side: "fighter_1", kind: "men")
      child.update!(lineup_1_set: true)

      child.assign_team_to_slot(1, b)

      tf.reload
      expect(child.reload.team_1_id).to eq b.id
      expect(child.lineup_1_set).to be false
      expect(tf.kenshi_1_id).to be_nil
      expect(tf.fight_points.where(fighter_side: "fighter_1")).to be_empty
    end

    it "is a no-op on first fill (nil -> team) and keeps no stale state" do
      child = create(:encounter, team_category: tc, team_1: nil, team_2: c)
      child.assign_team_to_slot(1, a)
      expect(child.reload.team_1_id).to eq a.id
      expect(child.team_fights).to be_empty
    end

    it "clears a descendant's recorded winner when an upstream result changes it out" do
      parent = create(:encounter, team_category: tc, team_1: a, team_2: b, winner: a)
      child = create(:encounter, team_category: tc, team_1: nil, team_2: c,
        parent_encounter_1: parent)
      child.assign_team_to_slot(1, a)
      child.update!(winner: a)

      parent.update!(winner: b) # a no longer advances

      expect(child.reload.winner_id).to be_nil
      expect(child.team_1_id).to eq b.id
    end

    # Guards the invariant that an already-SCORED descendant cannot keep stale
    # fight_points when an upstream result flips. Propagation routes the slot
    # change through assign_team_to_slot, which must invalidate the scored side.
    it "wipes a scored descendant's stale points when its feeding result flips" do
      r1 = create(:encounter, team_category: tc, team_1: a, team_2: b)
      r1_other = create(:encounter, team_category: tc, team_1: c, team_2: create(:team, team_category: tc), winner: c)
      final = create(:encounter, team_category: tc, team_1: nil, team_2: nil,
        parent_encounter_1: r1, parent_encounter_2: r1_other)

      r1.update!(winner: a) # a advances into final slot 1
      member(a)
      member(c)
      bout = create(:team_fight, encounter: final, kenshi_1: a.kenshis.first, kenshi_2: c.kenshis.first)
      create(:fight_point, scorable: bout, fighter_side: "fighter_1", kind: "men")
      final.update!(lineup_1_set: true)
      expect(final.reload.team_1_id).to eq a.id

      r1.update!(winner: b) # the feeding result flips: b now advances, not a

      bout.reload
      expect(final.reload.team_1_id).to eq b.id
      expect(bout.kenshi_1_id).to be_nil
      expect(bout.fight_points.where(fighter_side: "fighter_1")).to be_empty
      expect(final.lineup_1_set).to be false
    end
  end
end
