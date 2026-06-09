# frozen_string_literal: true

require "rails_helper"

RSpec.describe EncounterTreeComponent, type: :component do
  let(:tc) { create(:team_category, pool_size: 1, out_of_pool: 1) }

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
    # The link targets the enclosing tree frame (no _top) so the encounter swaps
    # in place; the encounter show renders a matching frame + "Back to tree".
    expect(page).to have_link("Encounter 1")
    expect(page).to have_no_css('a[data-turbo-frame="_top"]')
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
end
