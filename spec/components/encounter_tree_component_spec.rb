# frozen_string_literal: true

require "rails_helper"

RSpec.describe EncounterTreeComponent, type: :component do
  let(:tc) { create(:team_category, pool_size: 3, out_of_pool: 1) }

  def ranked_team(pool_number)
    create(:team, team_category: tc, pool_number: pool_number, pool_rank: 1)
  end

  it "renders a card per resolved round-1 encounter with team names" do
    a = ranked_team(1)
    b = ranked_team(2)
    TeamCategoryBracketBuilder.new(tc).call

    render_inline(described_class.new(team_category: tc, admin: true))

    expect(page).to have_text(a.name)
    expect(page).to have_text(b.name)
    # The link targets the encounter panel frame below the tree (no _top) so the
    # editor opens beneath the bracket; the encounter show renders that frame.
    expect(page).to have_link("Encounter 1")
    expect(page).to have_no_css('a[data-turbo-frame="_top"]')
  end

  it "targets the encounter panel frame so the bracket stays visible on click" do
    ranked_team(1)
    ranked_team(2)
    TeamCategoryBracketBuilder.new(tc).call

    render_inline(described_class.new(team_category: tc, admin: true))

    expect(page).to have_css(
      %(a[data-turbo-frame="encounter_panel_team_category_#{tc.id}"]),
      text: "Encounter 1"
    )
  end

  it "shows a 'Waiting for encounter N' placeholder for an unresolved round-2 slot" do
    ranked_team(1)
    ranked_team(2)
    ranked_team(3)
    ranked_team(4)
    TeamCategoryBracketBuilder.new(tc).call

    render_inline(described_class.new(team_category: tc, admin: true))

    # The final's slots forecast their undecided round-1 parents (mirrors the
    # individual tree's "Waiting for fight N").
    expect(page).to have_text("Waiting for encounter")
  end

  it "renders nothing meaningful when there is no bracket" do
    render_inline(described_class.new(team_category: tc, admin: true))
    expect(page).to have_css(".competition-tree")
  end

  it "ignores an ad-hoc encounter that has no round (does not crash on layout)" do
    a = create(:team, team_category: tc)
    b = create(:team, team_category: tc)
    create(:encounter, team_category: tc, team_1: a, team_2: b) # pool_number nil, round nil

    expect {
      render_inline(described_class.new(team_category: tc, admin: true))
    }.not_to raise_error
    expect(page).to have_text("No bracket yet")
  end

  it "shows a seeded round-1 slot's label once when its team is unresolved" do
    # out_of_pool 2 but only rank-1 teams exist, so the rank-2 slots carry a seed
    # (pool.rank) with no resolved team — the label must render once (prefix), not
    # be duplicated as the slot name.
    tc.update!(out_of_pool: 2)
    create(:team, team_category: tc, pool_number: 1, pool_rank: 1)
    create(:team, team_category: tc, pool_number: 2, pool_rank: 1)
    TeamCategoryBracketBuilder.new(tc).call

    render_inline(described_class.new(team_category: tc, admin: true))

    expect(page.text.scan("1.2").size).to eq 1
    expect(page.text.scan("2.2").size).to eq 1
  end

  describe "drag-to-swap eligibility" do
    let(:bracket_only) { create(:team_category, pool_size: nil) }

    def build_bracket(team_count = 4)
      create_list(:team, team_count, team_category: bracket_only)
      TeamCategoryBracketBuilder.new(bracket_only, random: Random.new(1)).call
    end

    def round_one
      bracket_only.bracket_encounters.where(round: 1).order(:position).to_a
    end

    it "marks an unscored round-1 slot swappable for an admin" do
      build_bracket
      component = described_class.new(team_category: bracket_only, admin: true)

      expect(component.send(:swappable?, round_one.first, 1)).to be true
    end

    it "marks nothing swappable for a non-admin" do
      build_bracket
      component = described_class.new(team_category: bracket_only, admin: false)

      expect(component.send(:swappable?, round_one.first, 1)).to be false
    end

    it "renders a grip on both slots of an unscored encounter" do
      build_bracket
      render_inline(described_class.new(team_category: bracket_only, admin: true))

      expect(page).to have_css(".competition-tree__grip", count: 4)
    end

    it "renders a grip on a bye card" do
      build_bracket(3)
      render_inline(described_class.new(team_category: bracket_only, admin: true))

      expect(page).to have_css(".competition-tree__match--bye .competition-tree__grip")
    end

    it "renders no grip for an encounter with a recorded result" do
      build_bracket
      first = round_one.first
      first.update!(winner: first.team_1)

      render_inline(described_class.new(team_category: bracket_only, admin: true))

      expect(page).to have_css(".competition-tree__grip", count: 2)
    end

    it "still renders grips once the lineups have been auto-seeded" do
      build_bracket
      round_one.first.update!(lineup_1_set: true, lineup_2_set: true)

      render_inline(described_class.new(team_category: bracket_only, admin: true))

      expect(page).to have_css(".competition-tree__grip", count: 4)
    end

    it "renders no grip for a non-admin" do
      build_bracket
      render_inline(described_class.new(team_category: bracket_only, admin: false))

      expect(page).to have_no_css(".competition-tree__grip")
    end

    it "carries the swap payload on a swappable slot" do
      build_bracket
      first = round_one.first
      render_inline(described_class.new(team_category: bracket_only, admin: true))

      expect(page).to have_css(
        %([data-encounter-id="#{first.id}"][data-slot="1"][data-team-id="#{first.team_1_id}"])
      )
    end

    it "marks nothing swappable in a pooled category" do
      ranked_team(1)
      ranked_team(2)
      TeamCategoryBracketBuilder.new(tc).call
      component = described_class.new(team_category: tc, admin: true)
      encounter = tc.bracket_encounters.find_by(round: 1)

      expect(component.send(:swappable?, encounter, 1)).to be false
    end
  end
end
