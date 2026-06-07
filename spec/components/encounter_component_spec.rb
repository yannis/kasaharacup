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

  def roster(team)
    Array.new(tc.team_size) do
      create(:kenshi, cup: tc.cup).tap { |k| create(:participation, category: tc, team: team, kenshi: k) }
    end
  end
end
