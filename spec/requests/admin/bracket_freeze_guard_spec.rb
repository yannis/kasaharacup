# frozen_string_literal: true

require "rails_helper"

# The server half of the bracket freeze (R3, R4). Sibling of
# pool_freeze_guard_spec, and the discrimination is what matters most here:
# Admin::FightPointsController and every encounter-scoped controller serve
# BOTH pool and bracket records, so a blanket guard would freeze the pool
# phase too — which is still being played while the bracket is locked.
RSpec.describe "Admin bracket freeze guard" do
  let(:cup) { create(:cup) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "individual category" do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3) }
    let(:bracket_fight) { create(:fight, individual_category: category) }
    let(:pool_fight) { create(:fight, :pool_fight, individual_category: category) }

    it "refuses generating, updating or rebuilding the tree" do
      bracket_fight
      category.freeze_bracket!

      post generate_bracket_admin_individual_category_path(category)
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present

      post generate_bracket_admin_individual_category_path(category, rebuild_started: true)
      expect(flash[:alert]).to be_present
    end

    it "refuses recording a bracket fight winner" do
      fight = bracket_fight
      category.freeze_bracket!

      patch admin_individual_category_fight_path(category, fight),
        params: {fight: {winner_id: fight.fighter_1_id}}, as: :turbo_stream

      expect(response).to have_http_status(:forbidden)
      expect(fight.reload.winner_id).to be_nil
    end

    it "refuses adding and removing a bracket fight's points" do
      fight = bracket_fight
      point = create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")
      category.freeze_bracket!

      post admin_individual_category_fight_fight_points_path(category, fight),
        params: {fight_point: {fighter_side: "fighter_1", kind: "kote"}}, as: :turbo_stream
      expect(response).to have_http_status(:forbidden)

      delete admin_individual_category_fight_fight_point_path(category, fight, point), as: :turbo_stream
      expect(response).to have_http_status(:forbidden)
      expect(fight.reload.fight_points.count).to eq 1
    end

    # The pool phase goes on while the bracket is locked. This is the case a
    # blanket guard would break.
    it "still allows pool fight points and winners while the bracket is frozen" do
      fight = pool_fight
      category.freeze_bracket!

      post admin_individual_category_pool_fight_fight_points_path(category, fight),
        params: {fight_point: {fighter_side: "fighter_1", kind: "men"}}, as: :turbo_stream
      expect(response).to have_http_status(:ok)

      patch admin_individual_category_pool_fight_path(category, fight),
        params: {pool_fight: {winner_id: fight.fighter_1_id, draw: false}}, as: :turbo_stream
      expect(response).to have_http_status(:ok)
      expect(fight.reload.winner_id).to eq fight.fighter_1_id
    end
  end

  describe "team category" do
    let(:category) { create(:team_category, cup: cup, team_size: 3) }
    let(:team_1) { create(:team, team_category: category, name: "Kyoto") }
    let(:team_2) { create(:team, team_category: category, name: "Osaka") }
    let(:kenshi_1) { create(:kenshi, cup: cup) }
    let(:kenshi_2) { create(:kenshi, cup: cup) }

    def encounter_for(pool_number: nil, round: nil, position: nil)
      create(:encounter, team_category: category, team_1: team_1, team_2: team_2,
        pool_number: pool_number, round: round, position: position,
        lineup_1_set: true, lineup_2_set: true)
    end

    def bracket_encounter = encounter_for(round: 1, position: 1)

    def pool_encounter = encounter_for(pool_number: 1)

    it "refuses generating and rebuilding the bracket" do
      bracket_encounter
      category.freeze_bracket!

      post generate_bracket_admin_team_category_path(category)

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it "refuses a team swap" do
      encounter = bracket_encounter
      category.freeze_bracket!

      post admin_team_category_encounter_team_swap_path(category, encounter),
        params: {slot: 1, team_id: team_2.id}, as: :turbo_stream

      expect(response).to have_http_status(:forbidden)
    end

    it "refuses a lineup, a lineup seeding and a daihyosen on a bracket encounter" do
      encounter = bracket_encounter
      category.freeze_bracket!

      patch admin_team_category_encounter_lineup_path(category, encounter),
        params: {team_id: team_1.id, kenshi_ids: [kenshi_1.id]}, as: :turbo_stream
      expect(response).to have_http_status(:forbidden)

      post admin_team_category_encounter_lineup_seed_path(category, encounter), as: :turbo_stream
      expect(response).to have_http_status(:forbidden)

      patch admin_team_category_encounter_daihyosen_path(category, encounter),
        params: {daihyosen: {kenshi_1_id: kenshi_1.id}}, as: :turbo_stream
      expect(response).to have_http_status(:forbidden)
    end

    it "refuses a bracket encounter's bout result and points" do
      encounter = bracket_encounter
      fight = create(:team_fight, encounter: encounter, kenshi_1: kenshi_1, kenshi_2: kenshi_2)
      category.freeze_bracket!

      patch admin_team_category_encounter_team_fight_path(category, encounter, fight),
        params: {team_fight: {draw: true}}, as: :turbo_stream
      expect(response).to have_http_status(:forbidden)

      post admin_team_category_encounter_team_fight_team_fight_points_path(category, encounter, fight),
        params: {team_fight_point: {fighter_side: "fighter_1", kind: "men"}}, as: :turbo_stream
      expect(response).to have_http_status(:forbidden)
      expect(fight.reload.draw).to be false
    end

    # The discrimination that matters: everything above stays available on a
    # POOL encounter while the bracket is frozen.
    it "leaves pool encounters fully editable while the bracket is frozen" do
      encounter = pool_encounter
      fight = create(:team_fight, encounter: encounter, kenshi_1: kenshi_1, kenshi_2: kenshi_2)
      category.freeze_bracket!

      patch admin_team_category_encounter_lineup_path(category, encounter),
        params: {team_id: team_1.id, kenshi_ids: [kenshi_1.id]}, as: :turbo_stream
      expect(response).to have_http_status(:ok)

      patch admin_team_category_encounter_team_fight_path(category, encounter, fight),
        params: {team_fight: {draw: true}}, as: :turbo_stream
      expect(response).to have_http_status(:ok)
      expect(fight.reload.draw).to be true

      post admin_team_category_encounter_team_fight_team_fight_points_path(category, encounter, fight),
        params: {team_fight_point: {fighter_side: "fighter_1", kind: "men"}}, as: :turbo_stream
      expect(response).to have_http_status(:ok)
    end
  end
end
