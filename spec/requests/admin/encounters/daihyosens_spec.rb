# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin encounter daihyosen" do
  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:admin) { create(:user, :admin) }
  let(:encounter) { create(:encounter, team_category: tc, team_1: t1, team_2: t2) }

  before { sign_in admin }

  def member(team)
    create(:kenshi, cup: cup).tap { |k| create(:participation, category: tc, team: team, kenshi: k) }
  end

  it "changes a rep to another member of the same team" do
    a1 = member(t1)
    a2 = member(t1)
    b1 = member(t2)
    daihyosen = create(:team_fight, encounter: encounter, daihyosen: true,
      position: tc.team_size + 1, kenshi_1: a1, kenshi_2: b1)

    patch admin_team_category_encounter_daihyosen_path(tc, encounter),
      params: {kenshi_1_id: a2.id}, as: :turbo_stream

    expect(daihyosen.reload.kenshi_1_id).to eq a2.id
    expect(daihyosen.kenshi_2_id).to eq b1.id # untouched
  end

  it "rejects a rep that is not on that team" do
    a1 = member(t1)
    b1 = member(t2)
    intruder = member(t2) # on team 2, not team 1
    daihyosen = create(:team_fight, encounter: encounter, daihyosen: true,
      position: tc.team_size + 1, kenshi_1: a1, kenshi_2: b1)

    patch admin_team_category_encounter_daihyosen_path(tc, encounter),
      params: {kenshi_1_id: intruder.id}, as: :turbo_stream

    expect(response).to have_http_status(:unprocessable_content)
    expect(daihyosen.reload.kenshi_1_id).to eq a1.id
  end

  it "returns 422 (not 500) when a rep is set on an unresolved team slot" do
    b1 = member(t2)
    # A round-1 bracket encounter whose team_1 has not resolved yet (nil, no
    # parent winner): member_id would call nil.kenshis and 500 without the guard.
    unresolved = create(:encounter, team_category: tc, team_1: nil, team_2: t2, round: 1)
    create(:team_fight, encounter: unresolved, daihyosen: true,
      position: tc.team_size + 1, kenshi_2: b1)

    patch admin_team_category_encounter_daihyosen_path(tc, unresolved),
      params: {kenshi_1_id: b1.id}, as: :turbo_stream

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects a rep change once the daihyosen has points" do
    a1 = member(t1)
    a2 = member(t1)
    b1 = member(t2)
    daihyosen = create(:team_fight, encounter: encounter, daihyosen: true,
      position: tc.team_size + 1, kenshi_1: a1, kenshi_2: b1)
    create(:fight_point, scorable: daihyosen, fighter_side: "fighter_1", kind: "men")

    patch admin_team_category_encounter_daihyosen_path(tc, encounter),
      params: {kenshi_1_id: a2.id}, as: :turbo_stream

    expect(response).to have_http_status(:unprocessable_content)
    expect(daihyosen.reload.kenshi_1_id).to eq a1.id
  end
end
