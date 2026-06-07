# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin fight points" do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup) }
  let(:fight) { create(:fight, individual_category: category) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "POST /admin/individual_categories/:cat/fights/:fight/fight_points" do
    it "creates a point and assigns the next position" do
      post admin_individual_category_fight_fight_points_path(category, fight), params: {
        fight_point: {fighter_side: "fighter_1", kind: "men"}
      }

      expect(response).to redirect_to(admin_individual_category_path(category))
      expect(fight.fight_points.count).to eq 1
      point = fight.fight_points.first
      expect(point.fighter_side).to eq "fighter_1"
      expect(point.kind).to eq "men"
      expect(point.position).to eq 1
    end

    it "rejects a third non-hansoku point on the same side" do
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "kote")

      post admin_individual_category_fight_fight_points_path(category, fight), params: {
        fight_point: {fighter_side: "fighter_1", kind: "ippon"}
      }

      expect(flash[:alert]).to include("Fighter already has 2 non-hansoku points")
      expect(fight.fight_points.count).to eq 2
    end

    it "rejects an unknown fighter_side without raising" do
      post admin_individual_category_fight_fight_points_path(category, fight), params: {
        fight_point: {fighter_side: "fighter_99", kind: "men"}
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(fight.fight_points).to be_empty
    end
  end

  describe "DELETE /admin/individual_categories/:cat/fights/:fight/fight_points/:id" do
    it "removes the point" do
      point = create(:fight_point, scorable: fight, fighter_side: "fighter_2", kind: "do")

      delete admin_individual_category_fight_fight_point_path(category, fight, point)

      expect(response).to redirect_to(admin_individual_category_path(category))
      expect(fight.fight_points).to be_empty
    end
  end

  describe "POST under the pool_fights nesting when the model validation fails" do
    let(:k1) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }
    let(:k2) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }
    let!(:pool_fight) {
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: k1, fighter_2: k2)
    }

    it "renders the pool with a flash alert instead of raising" do
      create(:fight_point, scorable: pool_fight, fighter_side: "fighter_1", kind: "men")
      create(:fight_point, scorable: pool_fight, fighter_side: "fighter_1", kind: "kote")

      post admin_individual_category_pool_fight_fight_points_path(category, pool_fight),
        params: {fight_point: {fighter_side: "fighter_1", kind: "ippon"}},
        as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fighter already has 2 non-hansoku points")
      expect(pool_fight.fight_points.count).to eq 2
    end
  end

  describe "POST under the pool_fights nesting" do
    let(:k1) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }
    let(:k2) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }
    let!(:pool_fight) {
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: k1, fighter_2: k2)
    }

    it "creates a point on a pool fight via the pool_fight_id parent key" do
      expect {
        post admin_individual_category_pool_fight_fight_points_path(category, pool_fight),
          params: {fight_point: {fighter_side: "fighter_1", kind: "men"}}
      }.to change { pool_fight.fight_points.count }.from(0).to(1)
      expect(response).to redirect_to(admin_individual_category_path(category))
    end
  end
end
