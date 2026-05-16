# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::PoolFights", type: :request do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup) }
  let(:admin) { create(:user, :admin) }
  let(:k1) { create(:kenshi, cup: cup) }
  let(:k2) { create(:kenshi, cup: cup) }
  let!(:participation_1) { create(:participation, category: category, kenshi: k1, pool_number: 1, pool_position: 1) }
  let!(:participation_2) { create(:participation, category: category, kenshi: k2, pool_number: 1, pool_position: 2) }

  before { sign_in admin }

  describe "POST /admin/individual_categories/:id/generate_pool_fights" do
    it "creates the cyclic pool fights" do
      expect {
        post generate_pool_fights_admin_individual_category_path(category)
      }.to change { category.pool_fights.count }.from(0).to(1)
      expect(response).to redirect_to(admin_individual_category_path(category))
    end

    it "is idempotent" do
      post generate_pool_fights_admin_individual_category_path(category)
      expect {
        post generate_pool_fights_admin_individual_category_path(category)
      }.not_to change { category.pool_fights.count }
    end
  end

  describe "POST /admin/individual_categories/:id/pool_fights" do
    it "creates a tiebreaker fight" do
      expect {
        post admin_individual_category_pool_fights_path(category),
          params: {pool_fight: {pool_number: 1, fighter_1_id: k1.id, fighter_2_id: k2.id}}
      }.to change { category.pool_fights.where(tiebreaker: true).count }.from(0).to(1)
      tiebreaker = category.pool_fights.where(tiebreaker: true).last
      expect(tiebreaker.fighter_1_id).to eq k1.id
      expect(tiebreaker.fighter_2_id).to eq k2.id
    end

    it "rejects mismatched pool fighters" do
      other_kenshi = create(:kenshi, cup: cup)
      create(:participation, category: category, kenshi: other_kenshi, pool_number: 2, pool_position: 1)

      post admin_individual_category_pool_fights_path(category),
        params: {pool_fight: {pool_number: 1, fighter_1_id: k1.id, fighter_2_id: other_kenshi.id}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(category.pool_fights.where(tiebreaker: true)).to be_empty
    end
  end

  describe "PATCH /admin/individual_categories/:id/pool_fights/:id" do
    let!(:fight) {
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: k1, fighter_2: k2)
    }

    it "sets a winner and clears any draw flag" do
      fight.update!(draw: true)
      patch admin_individual_category_pool_fight_path(category, fight),
        params: {pool_fight: {winner_id: k1.id}}
      expect(fight.reload).to have_attributes(winner_id: k1.id, draw: false)
    end

    it "sets draw=true and clears the winner" do
      fight.update!(winner: k1)
      patch admin_individual_category_pool_fight_path(category, fight),
        params: {pool_fight: {draw: "1"}}
      expect(fight.reload).to have_attributes(winner_id: nil, draw: true)
    end

    it "clears the outcome when both params are blank" do
      fight.update!(winner: k1)
      patch admin_individual_category_pool_fight_path(category, fight),
        params: {pool_fight: {winner_id: "", draw: "0"}}
      expect(fight.reload).to have_attributes(winner_id: nil, draw: false)
    end
  end

  describe "DELETE /admin/individual_categories/:id/pool_fights/:id" do
    let!(:fight) {
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: k1, fighter_2: k2)
    }

    it "deletes a tiebreaker" do
      fight.update_columns(tiebreaker: true)
      delete admin_individual_category_pool_fight_path(category, fight)
      expect(Fight.exists?(fight.id)).to be false
    end

    it "refuses to delete a non-tiebreaker pool fight" do
      delete admin_individual_category_pool_fight_path(category, fight)
      expect(Fight.exists?(fight.id)).to be true
      expect(response).to redirect_to(admin_individual_category_path(category))
    end
  end

  describe "POST /admin/individual_categories/:id/regenerate_pool_fights" do
    let!(:fight_pool_1) {
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: k1, fighter_2: k2)
    }
    let!(:fight_pool_2_p1) { create(:kenshi, cup: cup) }
    let!(:fight_pool_2_p2) { create(:kenshi, cup: cup) }
    let!(:fight_pool_2) {
      create(:participation, category: category, kenshi: fight_pool_2_p1, pool_number: 2, pool_position: 1)
      create(:participation, category: category, kenshi: fight_pool_2_p2, pool_number: 2, pool_position: 2)
      create(:fight, :pool_fight, individual_category: category, pool_number: 2,
        fighter_1: fight_pool_2_p1, fighter_2: fight_pool_2_p2)
    }

    it "regenerates only the targeted pool's fights, leaving other pools alone" do
      post regenerate_pool_fights_admin_individual_category_path(category), params: {pool_number: 1}
      expect(Fight.exists?(fight_pool_1.id)).to be false
      expect(Fight.exists?(fight_pool_2.id)).to be true
      expect(category.pool_fights.where(pool_number: 1).count).to eq 1
    end

    it "wipes the pool's tiebreakers too and recreates only the round-robin fights" do
      tiebreaker = create(:fight, :tiebreaker, individual_category: category, pool_number: 1,
        fighter_1: k1, fighter_2: k2)
      post regenerate_pool_fights_admin_individual_category_path(category), params: {pool_number: 1}
      expect(Fight.exists?(tiebreaker.id)).to be false
      expect(category.pool_fights.where(pool_number: 1, tiebreaker: true)).to be_empty
    end

    it "generates fights for a pool that had none" do
      empty_pool_k1 = create(:kenshi, cup: cup)
      empty_pool_k2 = create(:kenshi, cup: cup)
      create(:participation, category: category, kenshi: empty_pool_k1, pool_number: 3, pool_position: 1)
      create(:participation, category: category, kenshi: empty_pool_k2, pool_number: 3, pool_position: 2)

      expect {
        post regenerate_pool_fights_admin_individual_category_path(category), params: {pool_number: 3}
      }.to change { category.pool_fights.where(pool_number: 3).count }.from(0).to(1)
    end
  end
end
