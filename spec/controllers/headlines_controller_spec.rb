# frozen_string_literal: true

require "rails_helper"

RSpec.describe HeadlinesController do
  let!(:cup) { create :cup, start_on: Date.current + 20.days }

  describe "with 3 headlines in the database," do
    let(:user) { create :user }
    let(:user2) { create :user, admin: true }
    let(:headline1) { create :headline, title_fr: "headline1", cup: cup }
    let(:headline2) { create :headline, title_fr: "headline2", cup: cup }
    let(:headline3) { create :headline, title_fr: "headline3", cup: cup }

    context "when not logged in," do
      describe "on GET to :index without param," do
        before do
          get :index, params: {cup_id: cup.to_param, locale: I18n.locale}
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(assigns(:headlines)).not_to be_nil }
        it { expect(response).to render_template(:index) }
        it { expect(assigns(:headlines)).to match_array [headline1, headline2, headline3] }
        it { expect(flash).to be_empty }
      end

      describe "when GET to :show for headline1.id," do
        before do
          get :show, params: {id: headline1.to_param, cup_id: cup.to_param, locale: I18n.locale}
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(assigns(:headline)).to eq headline1 }
        it { expect(response).to render_template(:show) }
        it { expect(flash).to be_empty }
      end
    end

    describe "when logged in as basic" do
      let(:basic_user) { create :user }

      before { sign_in basic_user }

      describe "on GET to :index" do
        before do
          get :index, params: {cup_id: cup.to_param, locale: I18n.locale}
        end

        it { expect(basic_user).to be_valid_verbose }
        it { expect(assigns(:headlines)).not_to be_nil }
        it { expect(response).to render_template(:index) }
        it { expect(assigns(:headlines)).to match_array [headline1, headline2, headline3] }
        it { expect(flash).to be_empty }
      end

      describe "when GET to :show for headline1.id," do
        before {
          get :show, params: {cup_id: cup.to_param, id: headline1.to_param, locale: I18n.locale}
        }

        it { expect(response).to have_http_status(:success) }
        it { expect(assigns(:headline)).to eq headline1 }
        it { expect(response).to render_template(:show) }
        it { expect(flash).to be_empty }
      end
    end
  end
end
