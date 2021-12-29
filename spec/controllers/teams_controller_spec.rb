# frozen_string_literal: true

require "rails_helper"
RSpec.describe TeamsController, type: :controller do
  let!(:cup) { create :kendocup_cup, start_on: Date.current + 2.days }

  describe "with 3 teams in the database," do
    let(:user) { create :kendocup_user }
    let(:user2) { create :kendocup_user, admin: true }
    let(:team_category) { create :kendocup_team_category, name: "category1", cup: cup }
    let!(:team1) { create :kendocup_team, name: "team1", team_category: team_category }
    let!(:team2) { create :kendocup_team, name: "team2", team_category: team_category }
    let!(:team3) { create :kendocup_team, name: "team3", team_category: team_category }

    context "when not logged in," do
      describe "on GET to :index without param," do
        before do
          get :index, params: {cup_id: cup.to_param, locale: I18n.locale}
        end

        it { expect(response).to be_success }
        it { expect(assigns(:teams)).not_to be_nil }
        it { expect(expect(response)).to render_template(:index) }
        it { expect(assigns(:teams)).to match_array [team1, team2, team3] }
        it { expect(flash).to be_empty }
      end

      describe "when GET to :show for team1.id," do
        before do
          get :show, params: {cup_id: cup.to_param, id: team1.to_param, locale: I18n.locale}
        end

        it { expect(response).to be_success }
        it { expect(assigns(:team)).to eql team1 }
        it { expect(response).to render_template(:show) }
        it { expect(flash).to be_empty }
      end
    end

    context "when logged in as basic" do
      let(:basic_user) { create :kendocup_user }

      before {
        sign_in :user, scope: basic_user
      }

      describe "on GET to :index without param," do
        before do
          get :index, params: {cup_id: cup.to_param, locale: I18n.locale}
        end

        it { expect(basic_user).to be_valid_verbose }
        it { expect(assigns(:teams)).not_to be_nil }
        it { expect(response).to render_template(:index) }
        it { expect(assigns(:teams)).to match_array [team1, team2, team3] }
        it { expect(flash).to be_empty }
      end

      describe "when GET to :show for team1.id," do
        before do
          get :show, params: {id: team1.to_param, cup_id: cup.to_param, locale: I18n.locale}
        end

        it { expect(response).to be_success }
        it { expect(assigns(:team)).not_to be_nil }
        it { expect(response).to render_template(:show) }
        it { expect(flash).to be_empty }
        it { expect(assigns(:team)).to eql team1 }
      end
    end
  end
end
