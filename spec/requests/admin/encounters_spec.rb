# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin encounters" do
  let(:cup) { create(:cup) }
  let(:tc) { create(:team_category, cup: cup, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  def member(team)
    create(:kenshi, cup: cup).tap { |k| create(:participation, category: tc, team: team, kenshi: k) }
  end

  it "creates an encounter between two teams" do
    post admin_team_category_encounters_path(tc), params: {encounter: {team_1_id: t1.id, team_2_id: t2.id}}

    encounter = Encounter.last
    expect(encounter.team_1).to eq t1
    expect(response).to redirect_to(admin_team_category_encounter_path(tc, encounter))
  end

  it "sets a team's lineup, creating bouts" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    members = Array.new(3) { member(t1) }

    post lineup_admin_team_category_encounter_path(tc, encounter),
      params: {team_id: t1.id, kenshi_ids: members.map(&:id)}

    expect(encounter.team_fights.count).to eq 3
    expect(encounter.team_fights.order(:position).map(&:kenshi_1_id)).to eq members.map(&:id)
  end

  it "scores a bout and re-derives the encounter winner" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    fight = create(:team_fight, encounter: encounter, kenshi_1: member(t1), kenshi_2: member(t2))

    post admin_team_category_encounter_team_fight_team_fight_points_path(tc, encounter, fight),
      params: {team_fight_point: {fighter_side: "fighter_1", kind: "men"}}

    expect(fight.reload.winner_id).to eq fight.kenshi_1_id
    expect(encounter.reload.winner).to eq t1
  end

  it "removes a recorded point" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    fight = create(:team_fight, encounter: encounter, kenshi_1: member(t1), kenshi_2: member(t2))
    point = create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")

    delete admin_team_category_encounter_team_fight_team_fight_point_path(tc, encounter, fight, point)

    expect(fight.fight_points).to be_empty
    expect(fight.reload.winner_id).to be_nil
  end

  it "returns 422 for an invalid point kind instead of crashing" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    fight = create(:team_fight, encounter: encounter, kenshi_1: member(t1), kenshi_2: member(t2))

    post admin_team_category_encounter_team_fight_team_fight_points_path(tc, encounter, fight),
      params: {team_fight_point: {fighter_side: "fighter_1", kind: "bogus"}}

    expect(response).to have_http_status(:unprocessable_content)
    expect(fight.fight_points).to be_empty
  end

  it "adds a daihyosen fight" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)

    post daihyosen_admin_team_category_encounter_path(tc, encounter),
      params: {kenshi_1_id: member(t1).id, kenshi_2_id: member(t2).id}

    expect(encounter.team_fights.where(daihyosen: true).count).to eq 1
    expect(encounter.team_fights.find_by(daihyosen: true).position).to eq tc.team_size + 1
  end

  it "redirects non-admins away" do
    sign_out admin
    sign_in create(:user)

    post admin_team_category_encounters_path(tc), params: {encounter: {team_1_id: t1.id, team_2_id: t2.id}}

    expect(response).to redirect_to(root_url)
    expect(Encounter.count).to eq 0
  end

  it "renders the standalone encounter page" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)

    get admin_team_category_encounter_path(tc, encounter)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("#{t1.name} vs #{t2.name}")
    expect(response.body).to include("lineup") # the lineup forms render
  end

  describe "the encounter _summary partial" do
    def render_summary(encounter)
      ApplicationController.render(partial: "admin/encounters/summary", locals: {encounter: encounter})
    end

    def bout(encounter, pos, result)
      tf = encounter.team_fights.create!(position: pos,
        kenshi_1: create(:kenshi, cup: cup), kenshi_2: create(:kenshi, cup: cup))
      case result
      when 1 then create(:fight_point, scorable: tf, fighter_side: "fighter_1", kind: "men")
      when 2 then create(:fight_point, scorable: tf, fighter_side: "fighter_2", kind: "men")
      when :draw then tf.update!(draw: true)
      end
    end

    it "reads 'not yet scored' before the encounter is complete" do
      encounter = create(:encounter, team_category: tc, pool_number: 1, team_1: t1, team_2: t2)
      bout(encounter, 1, 1) # one bout scored, lineups not flagged complete
      expect(render_summary(encounter.reload)).to include("not yet scored")
    end

    it "shows the winner once complete" do
      encounter = create(:encounter, team_category: tc, pool_number: 1, team_1: t1, team_2: t2)
      bout(encounter, 1, 1)
      bout(encounter, 2, 1)
      bout(encounter, 3, 2)
      encounter.update!(lineup_1_set: true, lineup_2_set: true)
      expect(render_summary(encounter.reload)).to include("→ #{t1.name}")
    end

    it "shows hikiwake on a completed tie" do
      encounter = create(:encounter, team_category: tc, pool_number: 1, team_1: t1, team_2: t2)
      bout(encounter, 1, 1)
      bout(encounter, 2, 2)
      bout(encounter, 3, :draw)
      encounter.update!(lineup_1_set: true, lineup_2_set: true)
      expect(render_summary(encounter.reload)).to include("hikiwake")
    end
  end
end
