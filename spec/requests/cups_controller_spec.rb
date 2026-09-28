# frozen_string_literal: true

require "rails_helper"

RSpec.describe CupsController do
  let!(:cup1) { create(:cup, events: create_list(:event, 1)) }
  let!(:cup2) { create(:cup) }
  let!(:cup3) { create(:cup) }

  context "when not logged in" do
    describe "when GET to :show for cup1" do
      before { get(cup_path(cup1)) }

      it do
        expect(response).to have_http_status(:success)
        expect(assigns(:cup)).not_to be_nil
        expect(assigns(:cup)).to eql cup1
        expect(response).to render_template(:show)
        expect(flash).to be_empty
      end
    end

    describe "when GET to :show for a cup with products" do
      let!(:cup4) { create(:cup, events: create_list(:event, 1)) }
      let!(:product) { create(:product, cup: cup4) }

      before { get(cup_path(cup4)) }

      it "states that bank transfer fees are at the sender's charge" do
        expect(response.body).to include(CGI.escapeHTML(I18n.t("cups.show.fees.prepayment_transfer_fees")))
      end
    end

    describe "when GET to :show for a past cup" do
      let!(:past_cup) { create(:cup, start_on: 1.year.ago.to_date, end_on: 1.year.ago.to_date + 1.day) }

      before do
        create(:individual_category, cup: past_cup, name: "Junior U-12", max_age: 12)
        create(:individual_category, cup: past_cup, name: "Ladies", min_age: 16, gender_restriction: "female")
        create(:individual_category, cup: past_cup, name: "Junior U-18", min_age: 15, max_age: 18)
        create(:individual_category, cup: past_cup, name: "Open", min_age: 16)
        create(:individual_category, cup: past_cup, name: "Junior U-15", min_age: 12, max_age: 15)
        create(:team_category, cup: past_cup)
        get(cup_path(past_cup))
      end

      it "shows the results with Teams first, then Open, Ladies, U18, U15 and U12" do
        expect(response).to render_template(:show_past)
        headings = response.parsed_body.css("h3").map { |h3| h3.text.strip }.first(7)
        expect(headings).to eq [
          I18n.t("activerecord.models.team_category.one"),
          I18n.t("activerecord.models.individual_category.other"),
          "Open", "Ladies", "Junior u-18", "Junior u-15", "Junior u-12"
        ]
      end
    end

    describe "when GET to :show for a past cup with a team bracket" do
      let!(:past_cup) { create(:cup, start_on: 1.year.ago.to_date, end_on: 1.year.ago.to_date + 1.day) }
      let!(:team_category) { create(:team_category, cup: past_cup, pool_size: 3, out_of_pool: 1) }
      let!(:team_1) { create(:team, team_category: team_category, pool_number: 1, pool_rank: 1) }
      let!(:team_2) { create(:team, team_category: team_category, pool_number: 2, pool_rank: 1) }

      before do
        TeamCategoryBracketBuilder.new(team_category).call
        get(cup_path(past_cup))
      end

      it "shows the team bracket, without links into the admin" do
        tree = response.parsed_body.at_css(".competition-tree")
        expect(tree).to be_present
        expect(tree.text).to include(team_1.name, team_2.name, "Encounter 1")
        expect(tree.css("a")).to be_empty
      end
    end
  end
end
