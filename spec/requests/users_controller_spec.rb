# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersController do
  let!(:cup) { create(:cup, start_on: Date.current + 2.days) }
  let(:user) { create(:user) }
  let(:basic_user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }

  def valid_attributes
    {last_name: "a_last_name#{rand(1..1000)}", first_name: "a_first_name", email: "anemail@address.com",
     password: "jkasdkjd", password_confirmation: "jkasdkjd"}
  end

  describe "not signed in" do
    describe "GET #show" do
      before { get cup_user_path(cup) }

      it { should_be_asked_to_sign_in } # rubocop:disable RSpec/NoExpectationExample
    end
  end

  describe "signed in as basic" do
    before { sign_in basic_user }

    describe "GET show with self user_id" do
      before { get cup_user_path(cup) }

      it { expect(response).to have_http_status(:success) }
      it { expect(response).to render_template "show" }
      it { expect(assigns(:user)).to eq(basic_user) }
    end

    describe "GET show with purchases" do
      let!(:product) { create(:product, cup: cup, fee_chf: 10, fee_eu: 8) }
      let!(:kenshi) { create(:kenshi, cup: cup, user: basic_user) }
      let!(:purchase) { create(:purchase, product: product, kenshi: kenshi) }

      before { get cup_user_path(cup) }

      it { expect(response.body).to include("10 CHF") }
      it { expect(response.body).not_to include("€") }
    end
  end

  describe "When logged in as admin" do
    before { sign_in admin_user }

    describe "GET show with self user_id" do
      before { get cup_user_path(cup) }

      it { expect(assigns(:user)).to eq(admin_user) }
      it { expect(response).to have_http_status(:success) }
      it { expect(response).to render_template "show" }
    end
  end
end
