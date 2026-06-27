# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin team fights" do
  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:admin) { create(:user, :admin) }
  let(:encounter) do
    create(:encounter, team_category: tc, team_1: t1, team_2: t2,
      lineup_1_set: true, lineup_2_set: true)
  end
  let(:a) { create(:kenshi, cup: cup) }
  let(:b) { create(:kenshi, cup: cup) }

  before { sign_in admin }

  it "marks an eligible bout hikiwake and clears it again" do
    fight = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b)

    patch admin_team_category_encounter_team_fight_path(tc, encounter, fight),
      params: {team_fight: {draw: true}}, as: :turbo_stream
    expect(fight.reload.draw).to be true

    patch admin_team_category_encounter_team_fight_path(tc, encounter, fight),
      params: {team_fight: {draw: false}}, as: :turbo_stream
    expect(fight.reload.draw).to be false
  end

  it "rejects a draw on an ineligible (scored) bout" do
    fight = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b)
    create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")

    patch admin_team_category_encounter_team_fight_path(tc, encounter, fight),
      params: {team_fight: {draw: true}}, as: :turbo_stream

    expect(response).to have_http_status(:unprocessable_content)
    expect(fight.reload.draw).to be false
  end

  it "rejects a draw when the lineups are not both confirmed" do
    encounter.update!(lineup_2_set: false)
    fight = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b)

    patch admin_team_category_encounter_team_fight_path(tc, encounter, fight),
      params: {team_fight: {draw: true}}, as: :turbo_stream

    expect(response).to have_http_status(:unprocessable_content)
    expect(fight.reload.draw).to be false
  end

  it "auto-creates the daihyosen when the final hikiwake ties the encounter" do
    fighters_1 = Array.new(3) { create(:kenshi, cup: cup) }
    fighters_2 = Array.new(3) { create(:kenshi, cup: cup) }
    fighters_1.each { |k| create(:participation, category: tc, team: t1, kenshi: k) }
    fighters_2.each { |k| create(:participation, category: tc, team: t2, kenshi: k) }
    EncounterLineup.new(encounter).assign(t1, fighters_1.map(&:id))
    EncounterLineup.new(encounter).assign(t2, fighters_2.map(&:id))
    fights = encounter.team_fights.order(:position).to_a

    fights.each do |fight|
      patch admin_team_category_encounter_team_fight_path(tc, encounter, fight),
        params: {team_fight: {draw: true}}, as: :turbo_stream
    end

    daihyosen = encounter.team_fights.find_by(daihyosen: true)
    expect(daihyosen).to be_present
    expect(daihyosen.kenshi_1_id).to eq fighters_1.last.id
    expect(daihyosen.kenshi_2_id).to eq fighters_2.last.id
    # The triggering response already carries the new row (no stale-cache omission).
    expect(response.body).to include("Daihyōsen")
  end
end
