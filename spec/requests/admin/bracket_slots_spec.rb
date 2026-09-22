# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin bracket slots" do
  let(:cup) { create(:cup) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  shared_examples "a bracket slots endpoint" do
    it "answers a turbo stream carrying the tree and the waiting panel" do
      first, second = round_one

      patch slot_path(first, 1), params: {source_slot: "#{second.id}-1"},
        headers: {"Accept" => "text/vnd.turbo-stream.html"}

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq Mime[:turbo_stream].to_s
      expect(response.body).to include waiting_dom_id
    end

    it "answers 422 with the message when the move is refused" do
      first, = round_one

      patch slot_path(first, 1), params: {source_slot: "#{first.id}-1"},
        headers: {"Accept" => "text/vnd.turbo-stream.html"}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to include("already in this slot")
      expect(response.parsed_body["confirm"]).to be false
    end

    it "empties a slot on destroy" do
      first, = round_one

      delete slot_path(first, 1), headers: {"Accept" => "text/vnd.turbo-stream.html"}

      expect(response).to have_http_status(:ok)
      expect(first.reload.slot_entry(1)).to be_nil
    end

    it "refuses to place an entry that is already in the tree" do
      first, = round_one
      entry = first.slot_entry(1)

      patch slot_path(first, 1), params: {entry: entry.key},
        headers: {"Accept" => "text/vnd.turbo-stream.html"}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["message"]).to include("not waiting to be placed")
    end

    # 403, NOT 422: bracket_slot_controller.js offers a retry on every 422 that
    # carries confirm, and a freeze must never be force-able (R12).
    it "answers 403 on a frozen bracket" do
      category.update!(bracket_frozen_at: Time.current)
      first, second = round_one

      patch slot_path(first, 1), params: {source_slot: "#{second.id}-1"},
        headers: {"Accept" => "text/vnd.turbo-stream.html"}

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["message"]).to be_present
    end
  end

  context "on a team category" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2, team_size: 3) }

    before do
      (1..2).each do |pool|
        (1..2).each { |rank| create(:team, team_category: category, pool_number: pool, pool_rank: rank) }
      end
      TeamCategoryBracketBuilder.new(category).call
    end

    def round_one = category.bracket_encounters.where(round: 1).order(:position).to_a
    def slot_path(record, slot) = admin_team_category_bracket_slot_path(category, "#{record.id}-#{slot}")
    def waiting_dom_id = BracketWaitingComponent.dom_id_for(category)

    it_behaves_like "a bracket slots endpoint"
  end

  context "on an individual category" do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }

    before do
      (1..2).each do |pool|
        (1..2).each do |rank|
          create(:participation, category: category, pool_number: pool, pool_position: rank, pool_rank: rank)
        end
      end
      IndividualCategoryBracketBuilder.new(category).call
    end

    def round_one = category.bracket_fights.where(round: 1).order(:position).to_a
    def slot_path(record, slot) = admin_individual_category_bracket_slot_path(category, "#{record.id}-#{slot}")
    def waiting_dom_id = BracketWaitingComponent.dom_id_for(category)

    it_behaves_like "a bracket slots endpoint"
  end

  # The confirm-and-retry pair, which only a team bracket can reach: a fighter
  # order is an encounter's, and a fight has no lineup.
  describe "a move that would discard a hand-entered order" do
    let(:category) { create(:team_category, cup: cup, pool_size: nil, team_size: 3) }

    before do
      create_list(:team, 4, team_category: category).each do |team|
        create_list(:kenshi, 3, cup: cup).each do |kenshi|
          create(:participation, category: category, team: team, kenshi: kenshi)
        end
      end
      TeamCategoryBracketBuilder.new(category, random: Random.new(1)).call
    end

    def round_one = category.bracket_encounters.where(round: 1).order(:position).to_a

    it "answers 422 with confirm, then goes through on force" do
      first, second = round_one
      EncounterLineupSeeder.new(first).call
      first.update!(lineup_1_set_by_admin: true)
      path = admin_team_category_bracket_slot_path(category, "#{first.id}-1")

      patch path, params: {source_slot: "#{second.id}-1"},
        headers: {"Accept" => "text/vnd.turbo-stream.html"}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["confirm"]).to be true

      patch path, params: {source_slot: "#{second.id}-1", force: "true"},
        headers: {"Accept" => "text/vnd.turbo-stream.html"}

      expect(response).to have_http_status(:ok)
    end
  end
end
