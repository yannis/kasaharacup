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

  describe "the seed badge" do
    it "badges a seeded team on the pool card" do
      tc = create(:team_category, pool_size: 3)
      create(:team, team_category: tc, pool_number: 1, pool_position: 1, seed: 2)

      render_inline(described_class.new(team_category: tc, pool_number: 1, admin: true))

      expect(page).to have_css(".pool-standings__seed", text: "S2")
    end

    # Admin only, like the individual pool card's: the seeding is the
    # organizers' reading of the field, not a result.
    it "keeps the badge off a non-admin render" do
      tc = create(:team_category, pool_size: 3)
      create(:team, team_category: tc, pool_number: 1, pool_position: 1, seed: 2)

      render_inline(described_class.new(team_category: tc, pool_number: 1, admin: false))

      expect(page).to have_no_css(".pool-standings__seed")
    end

    it "badges nobody when no one is seeded" do
      tc = create(:team_category, pool_size: 3)
      create(:team, team_category: tc, pool_number: 1, pool_position: 1)

      render_inline(described_class.new(team_category: tc, pool_number: 1, admin: true))

      expect(page).to have_no_css(".pool-standings__seed")
    end
  end

  # Team twin of PoolComponent's frozen contract (R10).
  describe "when frozen" do
    let(:tc) { create(:team_category, pool_size: 3) }

    before do
      create(:team, team_category: tc, pool_number: 1, pool_position: 1)
      create(:team, team_category: tc, pool_number: 1, pool_position: 2)
      # A second pool, so the row's "Move to…" select has somewhere to offer.
      create(:team, team_category: tc, pool_number: 2, pool_position: 1)
    end

    def card
      render_inline(described_class.new(team_category: tc.reload, pool_number: 1, admin: true)).to_html
    end

    it "drops the grip, the move select and the drop wiring" do
      expect(card).to include("pool-standings__grip")

      tc.freeze_pools!

      frozen = card
      expect(frozen).not_to include("pool-standings__grip")
      expect(frozen).not_to include("pool-standings__move-select")
      expect(frozen).not_to include("data-move-url")
    end

    it "keeps the rank editor, and the subscription that carries the unfreeze" do
      tc.freeze_pools!

      frozen = card
      expect(frozen).to include("best_in_place")
      expect(frozen).to include("turbo-cable-stream-source")
    end

    # R5: a frozen bracket closes the formation too.
    it "is closed by the bracket flag as well" do
      tc.freeze_bracket!

      expect(card).not_to include("pool-standings__grip")
    end
  end
end
