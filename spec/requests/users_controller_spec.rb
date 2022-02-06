# frozen_string_literal: true

require "rails_helper"

RSpec.describe UsersController do
  let!(:cup) { create :cup, start_on: Date.current + 2.days }
  let(:user) { create :user }
  let(:basic_user) { create :user }
  let(:admin_user) { create :user, admin: true }

  def valid_attributes
    {last_name: "a_last_name#{rand(1..1000)}", first_name: "a_first_name", email: "anemail@address.com",
     password: "jkasdkjd", password_confirmation: "jkasdkjd"}
  end

  describe "not signed in" do
    describe "GET #show" do
      before { get cup_user_path(cup) }

      it { should_be_asked_to_sign_in }
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
