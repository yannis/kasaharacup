# frozen_string_literal: true

require "rails_helper"

RSpec.describe EncounterComponent, type: :component do
  let(:tc) { create(:team_category, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:encounter) { create(:encounter, team_category: tc, team_1: t1, team_2: t2) }

  it "renders the team names and a live tally" do
    render_inline(described_class.new(encounter: encounter))

    expect(page).to have_text(t1.name)
    expect(page).to have_text(t2.name)
    expect(page).to have_text("wins 0–0")
  end

  it "shows the derived winner when one team leads" do
    a = create(:kenshi, cup: tc.cup)
    b = create(:kenshi, cup: tc.cup)
    tf = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b)
    create(:fight_point, scorable: tf, fighter_side: "fighter_1", kind: "men")

    render_inline(described_class.new(encounter: encounter.reload))

    expect(page).to have_text("Winner: #{t1.name}")
  end

  it "shows the tie banner when both lineups are in and no winner" do
    a = roster(t1)
    b = roster(t2)
    EncounterLineup.new(encounter).assign(t1, a.map(&:id))
    EncounterLineup.new(encounter).assign(t2, b.map(&:id))

    render_inline(described_class.new(encounter: encounter.reload))

    expect(page).to have_text("Tied")
  end

  it "does not show the tie/daihyosen banner for a pool encounter" do
    encounter.update!(pool_number: 1)
    a = roster(t1)
    b = roster(t2)
    EncounterLineup.new(encounter).assign(t1, a.map(&:id))
    EncounterLineup.new(encounter).assign(t2, b.map(&:id))

    render_inline(described_class.new(encounter: encounter.reload))

    expect(page).not_to have_text("Tied")
  end

  describe "drag-to-reorder handles" do
    it "gives each filled admin fighter card a drag handle and a same-team drop zone" do
      a = roster(t1)
      EncounterLineup.new(encounter).assign(t1, a.map(&:id))

      render_inline(described_class.new(encounter: encounter.reload, admin: true))

      # One drop-zone row per fighter_1 slot, all tagged with that team's form id.
      expect(page).to have_css(
        ".pool-match__side--fighter_1 .pool-match__row[data-reorder-form][data-reorder-locked='false']",
        count: tc.team_size
      )
      expect(page).to have_css(
        ".pool-match__side--fighter_1 .pool-match__grip[draggable='true']",
        count: tc.team_size
      )
    end

    it "omits the handle and locks the drop zone once a side has scored" do
      a = roster(t1)
      b = roster(t2)
      EncounterLineup.new(encounter).assign(t1, a.map(&:id))
      EncounterLineup.new(encounter).assign(t2, b.map(&:id))
      scored = encounter.team_fights.order(:position).first
      create(:fight_point, scorable: scored, fighter_side: "fighter_1", kind: "men")

      render_inline(described_class.new(encounter: encounter.reload, admin: true))

      scored_row = "#encounter_#{encounter.id}_position_1 .pool-match__side--fighter_1"
      expect(page).to have_css("#{scored_row} .pool-match__row[data-reorder-locked='true']")
      expect(page).to have_no_css("#{scored_row} .pool-match__grip")
    end

    it "shows no drag handles to non-admins" do
      a = roster(t1)
      EncounterLineup.new(encounter).assign(t1, a.map(&:id))

      render_inline(described_class.new(encounter: encounter.reload, admin: false))

      expect(page).to have_no_css(".pool-match__grip")
    end
  end

  describe "unresolved bracket slots" do
    let(:a) { create(:team, team_category: tc) }

    it "renders a placeholder instead of crashing when a side is unresolved" do
      parent = create(:encounter, team_category: tc, team_1: a, team_2: create(:team, team_category: tc))
      encounter = create(:encounter, team_category: tc, team_1: nil, team_2: nil,
        round: 2, position: 1, parent_encounter_1: parent)

      render_inline(described_class.new(encounter: encounter, admin: true))

      expect(page).to have_text("To be decided")
    end
  end

  def roster(team)
    Array.new(tc.team_size) do
      create(:kenshi, cup: tc.cup).tap { |k| create(:participation, category: tc, team: team, kenshi: k) }
    end
  end
end
