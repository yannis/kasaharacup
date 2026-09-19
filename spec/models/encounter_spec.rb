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

  it "nullifies a slot when its team is deleted (instead of raising a FK error)" do
    team_1 = create(:team, team_category: tc)
    team_2 = create(:team, team_category: tc)
    encounter = create(:encounter, team_category: tc, team_1: team_1, team_2: team_2, winner: team_1)

    expect { team_1.destroy! }.not_to raise_error

    expect(encounter.reload.team_1_id).to be_nil
    expect(encounter.winner_id).to be_nil
    expect(encounter.team_2_id).to eq team_2.id
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

    it "broadcasts a tree replace when a bracket encounter's team changes" do
      a = create(:team, team_category: tc)
      b = create(:team, team_category: tc)
      encounter = create(:encounter, team_category: tc, team_1: a, team_2: b, round: 1, position: 1)
      allow(ActionCable.server).to receive(:broadcast)

      ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
      begin
        encounter.update!(team_2: create(:team, team_category: tc))
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

  describe "matchup invalidation broadcast" do
    # Regression: #invalidate_matchup DESTROYS the bouts, and TeamFight repaints
    # the panel only from an after_update_commit — so nothing told an open editor
    # its bouts were gone. It kept rendering them, and scoring one 404'd in
    # Admin::TeamFightPointsController. The tree is just as exposed on the swap
    # path, where the slot write's saved_changes no longer reach commit.
    it "repaints the panel and the tree when a slot re-resolution empties the matchup" do
      a = create(:team, team_category: tc)
      b = create(:team, team_category: tc)
      parent = create(:encounter, team_category: tc, team_1: a, team_2: b, round: 1, position: 1)
      child = create(:encounter, team_category: tc, team_1: nil, team_2: nil, round: 2, position: 1,
        parent_encounter_1: parent)
      child.assign_team_to_slot(1, a)
      create(:team_fight, encounter: child, position: 1)
      child.update!(lineup_1_set: true, lineup_2_set: true)
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      parent.update!(winner: b) # a no longer advances: child slot 1 re-resolves

      targets = ActiveJob::Base.queue_adapter.enqueued_jobs.map { |job| job[:args].to_s }
      expect(child.reload.team_fights).to be_empty
      expect(targets).to include(a_string_matching(/\bencounter_#{child.id}\b/))
      expect(targets).to include(a_string_matching(/encounter_tree_team_category_#{tc.id}/))
    end
  end

  describe "bye propagation to children" do
    let(:category) { create(:team_category, pool_size: nil) }
    let(:bye) { category.bracket_encounters.where(round: 1).detect(&:bye?) }
    let(:fight) { category.bracket_encounters.where(round: 1).detect { |e| !e.bye? } }
    let(:final) { category.bracket_encounters.find_by(round: 2) }

    before do
      create_list(:team, 3, team_category: category)
      TeamCategoryBracketBuilder.new(category, random: Random.new(1)).call
    end

    it "re-seeds the round-2 slot when the bye occupant changes" do
      replacement = fight.team_1
      bye.assign_team_to_slot(bye.bye_slot, replacement)

      slot = (final.parent_encounter_1_id == bye.id) ? 1 : 2
      expect(final.reload.public_send(:"team_#{slot}_id")).to eq replacement.id
    end

    it "does not touch the child slot when a non-bye encounter's team changes" do
      outsider = create(:team, team_category: category)
      slot = (final.parent_encounter_1_id == fight.id) ? 1 : 2
      fight.assign_team_to_slot(1, outsider)

      expect(final.reload.public_send(:"team_#{slot}_id")).to be_nil
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

    it "clears the stale matchup when a slot re-resolves to another team" do
      member(c)
      child = create(:encounter, team_category: tc, team_1: a, team_2: c)
      member(a)
      tf = create(:team_fight, encounter: child, kenshi_1: a.kenshis.first, kenshi_2: c.kenshis.first)
      create(:fight_point, scorable: tf, fighter_side: "fighter_1", kind: "men")
      child.update!(lineup_1_set: true, lineup_2_set: true)

      child.assign_team_to_slot(1, b)

      expect(child.reload.team_1_id).to eq b.id
      expect(child.team_fights).to be_empty
      expect(FightPoint.where(scorable: tf)).to be_empty
      # BOTH flags: c's order was entered to face a, who is no longer there.
      expect(child.lineup_1_set).to be false
      expect(child.lineup_2_set).to be false
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
    # change through assign_team_to_slot, which must invalidate the whole matchup.
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

      # The wipe is unavoidable (points are keyed by fighter_side), so it is at
      # least recorded — this is the only trace of a destroyed scoresheet.
      expect(Rails.logger).to receive(:warn)
        .with(/Encounter #{final.id}: matchup invalidated, discarding 1 bout and 1 recorded fight point/)

      r1.update!(winner: b) # the feeding result flips: b now advances, not a

      expect(final.reload.team_1_id).to eq b.id
      expect(final.team_fights).to be_empty
      expect(FightPoint.where(scorable: bout)).to be_empty
      expect(final.lineup_1_set).to be false
    end

    # A real 4-team bracket with full rosters, so the lineup seeder has something
    # to seed. Returns [category, round-1 encounters, final].
    def stocked_bracket
      category = create(:team_category, cup: tc.cup, pool_size: nil)
      create_list(:team, 4, team_category: category)
      TeamCategoryBracketBuilder.new(category, random: Random.new(1)).call
      category.teams.each do |team|
        create_list(:kenshi, category.team_size, cup: tc.cup).each do |kenshi|
          create(:participation, category: category, team: team, kenshi: kenshi)
        end
      end
      [category,
        category.bracket_encounters.where(round: 1).order(:position).to_a,
        category.bracket_encounters.find_by(round: 2)]
    end

    # Regression (#1310): correcting an earlier round's winner re-resolves the
    # child's slot, and invalidation used to empty only that side of every bout.
    # The opponent's seeded fighters were left alone in their bouts, which
    # TeamFight#forfeit reads as a walkover — recompute_winner! then recorded a
    # 5-0 win nobody fought, which advanced and locked the slot.
    it "does not hand the other side a forfeit win when a feeding result is corrected" do
      category, semis, final = stocked_bracket
      semis.each { |semi| semi.update!(winner: semi.team_1) }
      # Opening the final's panel seeds and confirms both of its lineups.
      EncounterLineupSeeder.new(final.reload).call

      # Without these the assertions below hold on an empty bout set, i.e.
      # whether or not seeding actually ran.
      expect(final.reload.team_fights.count).to eq category.team_size
      expect(final).to have_attributes(lineup_1_set: true, lineup_2_set: true)

      semis.first.update!(winner: semis.first.team_2) # an ordinary correction

      final.reload
      expect(final.winner_id).to be_nil
      expect(final.team_fights).to be_empty
      expect(final).to have_attributes(lineup_1_set: false, lineup_2_set: false)
    end

    # Regression (#1310, first-fill variant): #invalidate_matchup only fires on
    # RE-resolution, so it cannot reach this one. An admin opening the final's
    # panel while only one semi is decided seeds just that side, leaving every
    # bout with one fighter and an empty seat — which TeamFight#forfeit read as a
    # walkover, showing "Winner: X" and a 10-0 sweep before anyone had fought (the
    # component renders result.winner outside its both_teams_resolved? guard).
    # Fixed by gating #forfeit on both lineups being confirmed.
    it "does not derive a winner for a half-seeded matchup" do
      _category, semis, final = stocked_bracket

      semis.first.update!(winner: semis.first.team_1) # the other semi is still open
      EncounterLineupSeeder.new(final.reload).call
      final.reload

      expect(final.team_fights).not_to be_empty
      expect(final.team_fights.map(&:kenshi_2_id)).to all(be_nil)
      expect(final).to have_attributes(lineup_1_set: true, lineup_2_set: false)

      final.recompute_winner!

      result = final.reload.result
      expect(result.winner).to be_nil
      expect([result.team_1_ippons, result.team_2_ippons]).to eq [0, 0]
      expect(final.winner_id).to be_nil
    end
  end

  describe "#unscored? vs #pristine?" do
    let(:category) { create(:team_category, pool_size: nil) }

    def fresh_encounter
      create_list(:team, 2, team_category: category)
      TeamCategoryBracketBuilder.new(category, random: Random.new(1)).call
      category.bracket_encounters.find_by(round: 1)
    end

    it "treats a confirmed lineup as unscored but not pristine" do
      encounter = fresh_encounter
      # What EncounterLineupSeeder does the moment an admin opens the panel.
      encounter.update!(lineup_1_set: true, lineup_2_set: true)

      expect(encounter).to be_unscored
      expect(encounter).not_to be_pristine
    end

    it "is neither once a bout is scored" do
      encounter = fresh_encounter
      fight = create(:team_fight, encounter: encounter)
      create(:fight_point, scorable: fight, fighter_side: "fighter_1")

      expect(encounter.reload).not_to be_unscored
      expect(encounter).not_to be_pristine
    end

    it "is neither once a winner is recorded" do
      encounter = fresh_encounter
      encounter.update!(winner: encounter.team_1)

      expect(encounter).not_to be_unscored
      expect(encounter).not_to be_pristine
    end

    # Regression: a 0-0 hikiwake records no fight point and derives no winner,
    # so reading points alone reported an encounter the admin had decided as
    # untouched — and a draw-correction swap then destroyed those decisions.
    it "is neither once a bout is marked hikiwake" do
      encounter = fresh_encounter
      create(:team_fight, encounter: encounter, draw: true)

      expect(encounter.reload).not_to be_unscored
      expect(encounter).not_to be_pristine
    end

    it "is both on a freshly built encounter" do
      encounter = fresh_encounter

      expect(encounter).to be_unscored
      expect(encounter).to be_pristine
    end
  end
end
