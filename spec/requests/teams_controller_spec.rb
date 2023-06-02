# frozen_string_literal: true

require "rails_helper"
RSpec.describe TeamsController do
  let!(:cup) { create(:cup, start_on: Date.current + 2.days) }

  describe "with 3 teams in the database," do
    let(:user) { create(:user) }
    let(:user2) { create(:user, admin: true) }
    let(:team_category) { create(:team_category, name: "category1", cup: cup) }
    let!(:team1) { create(:team, name: "team1", team_category: team_category) }
    let!(:team2) { create(:team, name: "team2", team_category: team_category) }
    let!(:team3) { create(:team, name: "team3", team_category: team_category) }
    let!(:team1_participation) { create(:participation, category: team1.team_category, team: team1) }
    let!(:team3_participation) { create(:participation, category: team3.team_category, team: team3) }

    context "when not logged in," do
      describe "on GET to :index without param," do
        before do
          get(cup_teams_path(cup))
        end

        it do
          expect(response).to have_http_status(:success)
          expect(assigns(:teams)).not_to be_nil
          expect(expect(response)).to render_template(:index)
          expect(assigns(:teams)).to contain_exactly(team1, team3)
          expect(flash).to be_empty
        end
      end

      describe "when GET to :show for team1.id," do
        before do
          get(cup_team_path(cup, team1))
        end

        it do
          expect(response).to have_http_status(:success)
          expect(assigns(:team)).to eql team1
          expect(response).to render_template(:show)
          expect(flash).to be_empty
        end
      end
    end

    context "when logged in as basic" do
      let(:basic_user) { create(:user) }

      before { sign_in basic_user }

      describe "on GET to :index without param," do
        before do
          get(cup_teams_path(cup))
        end

        it do
          expect(basic_user).to be_valid_verbose
          expect(assigns(:teams)).not_to be_nil
          expect(response).to render_template(:index)
          expect(assigns(:teams)).to contain_exactly(team1, team3)
          expect(flash).to be_empty
        end
      end

      describe "when GET to :show for team1.id," do
        before do
          get(cup_team_path(cup, team1))
        end

        it do
          expect(response).to have_http_status(:success)
          expect(assigns(:team)).not_to be_nil
          expect(response).to render_template(:show)
          expect(flash).to be_empty
          expect(assigns(:team)).to eql team1
        end
      end
    end
  end
end
