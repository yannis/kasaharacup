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

  it "lists encounters, including bracket encounters whose teams are unresolved (nil)" do
    create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    # A round-1 bracket encounter resolves its teams through parent winners, so
    # team_1/team_2 are nil. The index must render them via the nil-safe
    # team_display_name helper rather than crashing on nil.name.
    create(:encounter, team_category: tc, team_1: nil, team_2: nil, round: 1)

    get admin_team_category_encounters_path(tc)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("To be decided")
  end

  it "renders a pool encounter without the bracket panel frame or Close button" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2, pool_number: 1)

    get admin_team_category_encounter_path(tc, encounter)

    expect(response.body).not_to include("encounter_panel_team_category_")
    expect(response.body).not_to include("encounter-panel#close")
  end

  it "sets a team's lineup, creating bouts" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    members = Array.new(3) { member(t1) }

    patch admin_team_category_encounter_lineup_path(tc, encounter),
      params: {team_id: t1.id, kenshi_ids: members.map(&:id)}

    expect(encounter.team_fights.count).to eq 3
    expect(encounter.team_fights.order(:position).map(&:kenshi_1_id)).to eq members.map(&:id)
  end

  it "keeps a blank middle slot at its position instead of moving it last" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    members = Array.new(3) { member(t1) }

    # The middle dropdown is left unselected ("—"), so it arrives as an empty string.
    patch admin_team_category_encounter_lineup_path(tc, encounter),
      params: {team_id: t1.id, kenshi_ids: [members[0].id, "", members[2].id]}

    expect(encounter.team_fights.order(:position).map(&:kenshi_1_id))
      .to eq [members[0].id, nil, members[2].id]
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
    expect(response.body).to include(t1.name) # team names head their columns
    expect(response.body).to include(t2.name)
    expect(response.body).to include("lineup") # the lineup forms render
  end

  it "pre-selects the assigned fighters in the in-table dropdowns" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    members = Array.new(3) { member(t1) }
    EncounterLineup.new(encounter).assign(t1, members.map(&:id))

    get admin_team_category_encounter_path(tc, encounter)

    expect(response).to have_http_status(:ok)
    members.each do |kenshi|
      expect(response.body).to include(%(<option selected="selected" value="#{kenshi.id}">))
    end
  end

  it "shows a fighter dropdown for every position before any lineup is set" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    member(t1)
    member(t2)
    expect(encounter.team_fights).to be_empty # pool encounters start without bouts

    get admin_team_category_encounter_path(tc, encounter)

    expect(response).to have_http_status(:ok)
    # team_size positions × 2 sides, each an auto-submitting kenshi dropdown.
    expect(response.body.scan('name="kenshi_ids[]"').size).to eq(tc.team_size * 2)
    form_id = "lineup_#{ActionView::RecordIdentifier.dom_id(encounter)}_team_#{t1.id}"
    expect(response.body).to include(%(form="#{form_id}"))
    expect(response.body).to include(%(<form id="#{form_id}"))
  end

  it "surfaces a lineup error in the panel instead of failing silently" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    outsider = create(:kenshi, cup: cup) # not a member of t1

    patch admin_team_category_encounter_lineup_path(tc, encounter),
      params: {team_id: t1.id, kenshi_ids: [outsider.id]}, as: :turbo_stream

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("member not on team")
  end

  it "renders the pool-match scoring layout for a bout" do
    encounter = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    create(:team_fight, encounter: encounter, kenshi_1: member(t1), kenshi_2: member(t2))

    get admin_team_category_encounter_path(tc, encounter)

    expect(response).to have_http_status(:ok)
    # Reuses the same two-sided scoring card as the individual category pools.
    expect(response.body).to include("pool-match__sides")
    expect(response.body).to include("pool-match__button")
  end

  describe "POST team_swap" do
    let(:bracket_only) { create(:team_category, cup: cup, pool_size: nil) }

    before do
      create_list(:team, 4, team_category: bracket_only)
      TeamCategoryBracketBuilder.new(bracket_only, random: Random.new(1)).call
    end

    def round_one
      bracket_only.bracket_encounters.where(round: 1).order(:position).to_a
    end

    it "swaps two round-1 occupants and redirects with a notice" do
      first, second = round_one
      moving_in = second.team_1

      post admin_team_category_encounter_team_swap_path(bracket_only, first),
        params: {slot: 1, team_id: moving_in.id}

      expect(response).to redirect_to(admin_team_category_path(bracket_only))
      expect(flash[:notice]).to be_present
      expect(first.reload.team_1).to eq moving_in
    end

    it "redirects with an alert on an invalid swap" do
      first, second = round_one
      second.update!(winner: second.team_1)

      post admin_team_category_encounter_team_swap_path(bracket_only, first),
        params: {slot: 1, team_id: second.team_1.id}

      expect(response).to redirect_to(admin_team_category_path(bracket_only))
      expect(flash[:alert]).to include("recorded results")
      expect(first.reload.team_1).not_to eq second.team_1
    end

    it "renders swap selects on a pristine bracket-only round-1 encounter" do
      get admin_team_category_encounter_path(bracket_only, round_one.first)

      expect(response.body).to include("swap-team__form")
    end

    it "renders no swap controls once the encounter has results" do
      encounter = round_one.first
      encounter.update!(winner: encounter.team_1)

      get admin_team_category_encounter_path(bracket_only, encounter)

      expect(response.body).not_to include("swap-team__form")
    end

    it "renders no swap controls on a final (round 2)" do
      final = bracket_only.bracket_encounters.find_by(round: 2)

      get admin_team_category_encounter_path(bracket_only, final)

      expect(response.body).not_to include("swap-team__form")
    end
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
