# frozen_string_literal: true

require "rails_helper"

describe "Admin team lineup drag-to-reorder", :js do
  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:admin) { create(:user, :admin) }

  def member(team, name)
    create(:kenshi, cup: cup, first_name: name, last_name: "X").tap do |k|
      create(:participation, category: tc, team: team, kenshi: k)
    end
  end

  def position_kenshi_ids(encounter)
    encounter.team_fights.order(:position).pluck(:kenshi_1_id)
  end

  it "swaps two fighters in a team column by dragging one onto the other" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    a = member(t1, "Aaa")
    b = member(t1, "Bbb")
    c = member(t1, "Ccc")
    member(t2, "Opp")

    EncounterLineup.new(encounter).assign(t1, [a.id, b.id, c.id])
    signin_and_visit(admin, admin_team_category_encounter_path(tc, encounter))

    col = ".pool-match__side--fighter_1"
    pos1_grip = find("#encounter_#{encounter.id}_position_1 #{col} .pool-match__grip")
    pos3_row = find("#encounter_#{encounter.id}_position_3 #{col} .pool-match__row")

    # Drag position 1 onto position 3 — a swap, so only those two exchange.
    pos1_grip.drag_to(pos3_row, html5: true)

    # Wait for the auto-submit + Turbo morph to land the new order.
    within("#encounter_#{encounter.id}_position_1 #{col}") do
      expect(page).to have_select("kenshi_ids[]", selected: c.full_name)
    end

    expect(position_kenshi_ids(encounter.reload)).to eq [c.id, b.id, a.id]
  end

  it "does not swap across teams (each column reorders independently)" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    a = member(t1, "Aaa")
    member(t1, "Bbb")
    member(t1, "Ccc")
    opp = member(t2, "Opp")

    EncounterLineup.new(encounter).assign(t1, [a.id])
    EncounterLineup.new(encounter).assign(t2, [opp.id])
    signin_and_visit(admin, admin_team_category_encounter_path(tc, encounter))

    t1_grip = find("#encounter_#{encounter.id}_position_1 .pool-match__side--fighter_1 .pool-match__grip")
    t2_row = find("#encounter_#{encounter.id}_position_1 .pool-match__side--fighter_2 .pool-match__row")

    t1_grip.drag_to(t2_row, html5: true)

    # The cross-team drop is rejected client-side, so nothing changed.
    expect(position_kenshi_ids(encounter.reload).first).to eq a.id
    expect(encounter.team_fights.order(:position).first.kenshi_2_id).to eq opp.id
  end
end
