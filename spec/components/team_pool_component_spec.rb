# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamPoolComponent, type: :component do
  it "renders a standings row per team with the pool number" do
    tc = create(:team_category, pool_size: 3)
    t1 = create(:team, team_category: tc, pool_number: 1, pool_position: 1)
    t2 = create(:team, team_category: tc, pool_number: 1, pool_position: 2)

    render_inline(described_class.new(team_category: tc, pool_number: 1, admin: false))

    expect(page).to have_text("Pool 1")
    expect(page).to have_text(t1.name)
    expect(page).to have_text(t2.name)
  end

  it "wraps the standings in a broadcast-targetable sub-panel" do
    tc = create(:team_category, pool_size: 3)
    create(:team, team_category: tc, pool_number: 1, pool_position: 1)

    render_inline(described_class.new(team_category: tc, pool_number: 1, admin: true))

    expect(page).to have_css("#team_pool_standings_#{tc.id}_1 table.pool-standings")
  end

  describe "inline encounter editors" do
    let(:tc) { create(:team_category, team_size: 3, pool_size: 3) }
    let(:t1) { create(:team, team_category: tc, pool_number: 1, pool_position: 1) }
    let(:t2) { create(:team, team_category: tc, pool_number: 1, pool_position: 2) }
    let!(:encounter) { create(:encounter, team_category: tc, pool_number: 1, team_1: t1, team_2: t2) }

    it "renders a collapsible editor per encounter for admins" do
      render_inline(described_class.new(team_category: tc, pool_number: 1, admin: true))

      expect(page).to have_css("details.pool-encounter summary#summary_encounter_#{encounter.id}")
      expect(page).to have_text("#{t1.name} vs #{t2.name}")
      expect(page).to have_text("not yet scored") # complete?-before-winner: unscored reads "not yet scored"
      # the embedded editor (lineup/scoring forms) is hidden inside a closed <details>
      expect(page).to have_css("details.pool-encounter form", visible: false)
    end

    it "auto-seeds the inline editor so its bouts open pre-filled with fighter names" do
      [t1, t2].each do |team|
        create(:participation, category: tc, team: team, kenshi: create(:kenshi, cup: tc.cup))
      end

      render_inline(described_class.new(team_category: tc, pool_number: 1, admin: true))

      expect(page).to have_css(".encounter[data-lineup-seed-url-value]", visible: false)
    end

    it "shows a read-only link list (no editor) for non-admins" do
      render_inline(described_class.new(team_category: tc, pool_number: 1, admin: false))

      expect(page).not_to have_css("details.pool-encounter")
      expect(page).to have_link("#{t1.name} vs #{t2.name}")
    end
  end
end
