require 'rails_helper'
RSpec.describe KenshisController, type: :controller do

  def valid_params
    {last_name: "a_last_name", female: false, first_name: "a_first_name", grade: '1Dan', club_name: "a_club", cup: cup, dob: 20.years.ago}
  end

  before {
    Timecop.travel(cup.deadline-5.days)
  }

  describe "with 3 kenshis in the database," do

    let!(:cup) {create :kendocup_cup, start_on: "#{Date.current.year}-11-30"}
    let(:user) {create :kendocup_user}
    let(:user2) {create :kendocup_user, admin: true}
    let(:kenshi1) {create :kendocup_kenshi, last_name: 'kenshi1', user_id: user.to_param, cup: cup}
    let(:kenshi2) {create :kendocup_kenshi, last_name: 'kenshi2', user_id: user2.to_param, cup: cup}
    let(:kenshi3) {create :kendocup_kenshi, last_name: 'kenshi3', user_id: user.to_param, cup: cup}

    KENSHI_CONT_METHODS = ["get :new, locale: I18n.locale, cup_id: cup.to_param", "post :create, cup_id: cup.to_param, kenshi: {last_name: 'just created kenshi'}, locale: I18n.locale", "put :update, cup_id: cup.to_param, id: kenshi1.to_param, kenshi: {last_name: 'just updated kenshi'}, locale: I18n.locale", "delete :destroy, cup_id: cup.to_param, id: kenshi1.to_param, locale: I18n.locale"]

    context "when not logged in," do

      describe "on GET to :index without param," do
        before do
          get :index, cup_id: cup.to_param, locale: I18n.locale
        end

        it {expect(response).to be_success}
        it {expect(assigns(:kenshis)).to_not be_nil}
        it {expect(response).to render_template(:index)}
        it {expect(assigns(:kenshis)).to match_array [kenshi1, kenshi2, kenshi3]}
        it {expect(flash).to be_empty}
      end

      describe "on GET to :index with param :user_id" do
        before {get :index, cup_id: cup.to_param, user_id: user.to_param, locale: I18n.locale}

        it {expect(response).to redirect_to cup_kenshis_path(cup)}
        it {expect(flash).to be_empty}
      end

      describe "when GET to :show for kenshi1.id," do
        before {get :show, cup_id: cup.to_param, id: kenshi1.to_param, locale: I18n.locale}

        it {expect(response).to be_success}
        it {expect(assigns(:kenshi)).to eql kenshi1}
        it {expect(response).to render_template(:show)}
        it {expect(flash).to be_empty}
      end

      describe "when GET to :show for kenshi1.id with param :user_id" do
        before {get :show, cup_id: cup.to_param, user_id: user.to_param, id: kenshi1.to_param, locale: I18n.locale}

        it {expect(response).to redirect_to cup_kenshi_path(cup, kenshi1.id)}
        it {expect(flash).to be_empty}
      end

      KENSHI_CONT_METHODS.each do |m|
        describe "on #{m}" do
          before :each do
            eval(m)
          end
          should_be_asked_to_sign_in
        end
      end
    end

    describe "when logged in" do
      let(:basic_user){ create :kendocup_user }
      let(:basic_user_kenshi){create :kendocup_kenshi, user_id: basic_user.id, cup: cup}
      before{ sign_in basic_user }

      describe "on GET to :index without param," do
        before :each do
          get :index, cup_id: cup.to_param, locale: I18n.locale
        end

        it {expect(assigns(:kenshis)).to_not be_nil}
        it {expect(response).to render_template(:index)}
        it {expect(assigns(:kenshis)).to match_array [kenshi1, kenshi2, kenshi3]}
        it {expect(flash).to be_empty}
      end

      describe "when GET to :show for kenshi1.id," do
        before { get :show, cup_id: cup.to_param, id: kenshi1.to_param, locale: I18n.locale}
        it {expect(response).to be_success}
        it {expect(assigns(:kenshi)).to_not be_nil}
        it {expect(response).to render_template(:show)}
        it {expect(flash).to be_empty}
        it {expect(assigns(:kenshi)).to eql kenshi1}
      end

      describe "when GET to :new with user_id: basic_user.to_param," do
        before {get :new, cup_id: cup.to_param, user_id: basic_user.to_param, locale: I18n.locale}
        it {expect(assigns(:current_user)).to eql basic_user
        }
        it {expect(response).to be_success}
        it {expect(assigns(:kenshi)).to_not be_nil}
        it {expect(response).to render_template(:new)}
        it {expect(flash).to be_empty}
      end

      describe "when GET to :new without user_id param," do
        before {get :new, cup_id: cup.to_param, locale: I18n.locale}
        it {expect(response).to redirect_to new_cup_user_kenshi_path(cup,basic_user)}
      end

      describe "when POST to :create with valid data," do
        before {post :create, kenshi: valid_params, cup_id: cup.to_param, user_id: basic_user.to_param, locale: I18n.locale}
        it {expect(assigns(:kenshi)).to be_an_instance_of Kendocup::Kenshi}
        it {expect(assigns(:kenshi)).to be_valid_verbose}
        it {expect(response).to redirect_to(cup_user_path(cup, basic_user)) }
        it {expect(flash[:notice]).to match /Kenshi successfully registered/}
        it {expect(assigns(:kenshi).user_id).to eql basic_user.id}
      end

      describe "when POST to :create with invalid data," do
        before {post :create, kenshi: {last_name: ""}, cup_id: cup.to_param, user_id: basic_user.to_param, locale: I18n.locale}
        it {expect(assigns(:kenshi)).to_not be_nil}
        it {expect(assigns(:kenshi)).to be_an_instance_of Kendocup::Kenshi}
        it {expect(assigns(:kenshi)).to_not be_valid_verbose}
        it {expect(response).to render_template(:new)}
        it {expect(flash.now[:alert]).to match /Kenshi not registered/}
      end

      describe "on GET to :edit with :id = basic_user_kenshi.to_param," do
        before { get :edit, cup_id: cup.to_param, id: basic_user_kenshi.to_param, locale: I18n.locale }
        it {expect(response).to be_success}
        it {expect(assigns(:kenshi)).to eql basic_user_kenshi}
        it {expect(response).to render_template(:edit)}
      end

      describe "on GET to :edit with :id = kenshi1.to_param," do
        before {get :edit, cup_id: cup.to_param, id: kenshi1.to_param, locale: I18n.locale}
        should_not_be_authorized
      end

      describe "on PUT to :update with :id = basic_user_kenshi.to_param and valid data"  do
        before {put :update, cup_id: cup.to_param, id: basic_user_kenshi.to_param, kenshi: {last_name: "alaNma2"}, locale: I18n.locale}

        it {expect(assigns(:kenshi)).to eql basic_user_kenshi}
        it {expect(response).to redirect_to(cup_user_path(cup, basic_user_kenshi.user))}
        it {expect(flash[:notice]).to match /Registration successfully updated/}
        it {expect(basic_user_kenshi.reload.last_name).to eql 'Alanma2'}
      end

      describe "on PUT to :update with :id = basic_user_kenshi.to_param and invalid data," do
        before {put :update, id: basic_user_kenshi.to_param, cup_id: cup.to_param, kenshi: {last_name: ""}, locale: I18n.locale}

        it {expect(assigns(:kenshi)).to eql basic_user_kenshi}
        it {expect(response).to render_template(:edit)}
        it {expect(flash[:alert]).to match /Kenshi not updated/}
      end

      describe "on PUT to :update with :id = kenshi1.to_param and valid data," do
        before {put :update, id: kenshi1.to_param, cup_id: cup.to_param, kenshi: {last_name: "alaNma2"}, locale: I18n.locale}
        should_not_be_authorized
      end

      describe "on DELETE to :destroy with :id = basic_user_kenshi.to_param," do
        before {
          basic_user_kenshi.save
          @kenshi_count = Kendocup::Kenshi.count
          delete :destroy, cup_id: cup.to_param, id: basic_user_kenshi.to_param, locale: I18n.locale
        }

        it {expect(assigns(:kenshi)).to eql basic_user_kenshi}
        it {expect(@kenshi_count - Kendocup::Kenshi.count).to eql 1}
        it {expect(flash[:notice]).to match /Kenshi successfully destroyed/}
        it {expect(response).to redirect_to(cup_user_path(cup, basic_user))}
      end

      describe "on DELETE to :destroy with :id = kenshi1.to_param," do
        before {delete :destroy, cup_id: cup.to_param, id: kenshi1.to_param, locale: I18n.locale}
        should_not_be_authorized
      end

      context "when deadline is passed" do
        before {
          Timecop.travel(cup.deadline+5.minutes)
        }

        describe "when GET to :new with user_id: basic_user.to_param," do
          before {get :new, cup_id: cup.to_param, user_id: basic_user.to_param, locale: I18n.locale}
          deadline_passed
        end

        describe "on GET to :edit with :id = basic_user_kenshi.to_param," do
          before { get :edit, cup_id: cup.to_param, id: basic_user_kenshi.to_param, locale: I18n.locale }
          deadline_passed
        end

        describe "on PUT to :update with :id = basic_user_kenshi.to_param and valid data," do
          before {put :update, cup_id: cup.to_param, id: basic_user_kenshi.to_param, kenshi: {last_name: "AlaNma2"}, locale: I18n.locale}
          deadline_passed
        end

        describe "when POST to :create with valid data," do
          before {post :create, cup_id: cup.to_param, kenshi: valid_params, locale: I18n.locale}
          deadline_passed
        end

        describe "on DELETE to :destroy with :id = basic_user_kenshi.to_param," do
          before :each do
            basic_user_kenshi.save
            @kenshi_count = Kendocup::Kenshi.count
            delete :destroy, cup_id: cup.to_param, id: basic_user_kenshi.to_param, locale: I18n.locale
          end
          deadline_passed
        end
      end
    end
  end
end
