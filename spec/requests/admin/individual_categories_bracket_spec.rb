# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin individual category brackets" do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 1) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /admin/individual_categories/:id" do
    it "renders pool positions and pool ranks as editable in place" do
      create_qualified_participation(pool_number: 1, pool_rank: 1)

      get admin_individual_category_path(category)

      expect(response.body).to include("data-bip-attribute=\"pool_position\"")
      expect(response.body).to include("data-bip-attribute=\"pool_rank\"")
      expect(response.body).to include("/assets/admin-")
      expect(response.body).to include("type=\"module\"")
    end
  end

  describe "POST /admin/individual_categories/:id/generate_bracket" do
    it "generates a bracket for the category" do
      create_qualified_participation(pool_number: 1, pool_rank: 1)
      create_qualified_participation(pool_number: 2, pool_rank: 1)

      post generate_bracket_admin_individual_category_path(category)

      expect(response).to redirect_to(admin_individual_category_path(category))
      expect(category.fights.count).to eq 1
      expect(flash[:notice]).to eq I18n.t("admin.competition_trees.generate_bracket.notice")
    end

    it "redirects non-admin users away" do
      sign_out admin
      sign_in create(:user)

      post generate_bracket_admin_individual_category_path(category)

      expect(response).to redirect_to(root_url)
      expect(category.fights).to be_empty
    end
  end

  describe "GET /admin/individual_categories/:id/competition_tree_pdf" do
    it "downloads a PDF representation of the bracket" do
      create_qualified_participation(pool_number: 1, pool_rank: 1)
      create_qualified_participation(pool_number: 2, pool_rank: 1)
      IndividualCategoryBracketBuilder.new(category).call

      get competition_tree_pdf_admin_individual_category_path(category)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "application/pdf"
      expect(response.body[0, 4]).to eq "%PDF"
    end

    it "produces a PDF even when no bracket has been generated" do
      get competition_tree_pdf_admin_individual_category_path(category)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "application/pdf"
    end

    it "produces a PDF when fights have recorded points including hansoku" do
      create_qualified_participation(pool_number: 1, pool_rank: 1)
      create_qualified_participation(pool_number: 2, pool_rank: 1)
      IndividualCategoryBracketBuilder.new(category).call
      fight = category.fights.first
      create(:fight_point, fight: fight, fighter_side: "fighter_1", kind: "men")
      create(:fight_point, fight: fight, fighter_side: "fighter_2", kind: "hansoku")

      get competition_tree_pdf_admin_individual_category_path(category)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "application/pdf"
      expect(response.body[0, 4]).to eq "%PDF"
    end
  end

  describe "PATCH /admin/individual_categories/:category_id/fights/:id" do
    it "records the fight winner" do
      fight = create(:fight, individual_category: category)

      patch admin_individual_category_fight_path(category, fight), params: {
        fight: {winner_id: fight.fighter_1_id}
      }

      expect(response).to redirect_to(admin_individual_category_path(category))
      fight.reload
      expect(fight.winner).to eq fight.fighter_1
    end

    it "clears the winner when winner_id is blank" do
      fight = create(:fight, individual_category: category)
      fight.update!(winner: fight.fighter_1)

      patch admin_individual_category_fight_path(category, fight), params: {
        fight: {winner_id: ""}
      }

      expect(response).to redirect_to(admin_individual_category_path(category))
      expect(fight.reload.winner).to be_nil
    end

    it "refreshes the competition tree in place for turbo stream requests" do
      fight = create(:fight, individual_category: category)

      patch admin_individual_category_fight_path(category, fight),
        params: {fight: {winner_id: fight.fighter_1_id}},
        headers: {"ACCEPT" => "text/vnd.turbo-stream.html"}

      expect(response.media_type).to eq Mime[:turbo_stream]
      expect(response.body).to include("action=\"replace\"")
      expect(response.body).to include("method=\"morph\"")
      expect(response.body).to include("competition_tree_individual_category_#{category.id}")
      expect(response.body).to include(fight.fighter_1.poster_name)
    end
  end

  def create_qualified_participation(pool_number:, pool_rank:)
    create(:participation,
      category: category,
      pool_number: pool_number,
      pool_position: pool_rank,
      pool_rank: pool_rank)
  end
end
