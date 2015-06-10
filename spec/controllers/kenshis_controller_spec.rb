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

    KENSHI_CONT_METHODS = ["get :new, locale: I18n.locale", "post :create, kenshi: {last_name: 'just created kenshi'}, locale: I18n.locale", "put :update, id: kenshi1.to_param, kenshi: {last_name: 'just updated kenshi'}, locale: I18n.locale", "delete :destroy, id: kenshi1.to_param, locale: I18n.locale"]

    context "when not logged in," do

      describe "on GET to :index without param," do
        before do
          get :index, locale: I18n.locale
        end

        it {response.should be_success}
        it {assigns(:kenshis).should_not be_nil}
        it {response.should render_template(:index)}
        it {assigns(:kenshis).should =~ [kenshi1, kenshi2, kenshi3]}
        it {flash.should be_empty}
      end

      describe "on GET to :index with param :user_id" do
        before :each do
          get :index, user_id: user.to_param, locale: I18n.locale
        end

        it {expect(response).to redirect_to kenshis_path}
        it {flash.should be_empty}
      end

      describe "when GET to :show for kenshi1.id," do
        before :each do
          get :show, id: kenshi1.to_param, locale: I18n.locale
        end

        it {response.should be_success}
        it {assigns(:kenshi).should == kenshi1}
        it {response.should render_template(:show)}
        it {flash.should be_empty}
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
          get :index, locale: I18n.locale
        end

        it {assigns(:kenshis).should_not be_nil}
        it {response.should render_template(:index)}
        it {assigns(:kenshis).should =~ [kenshi1, kenshi2, kenshi3]}
        it {flash.should be_empty}
      end

      describe "when GET to :show for kenshi1.id," do
        before :each do
          get :show, id: kenshi1.to_param, locale: I18n.locale
        end

        it {response.should be_success}
        it {assigns(:kenshi).should_not be_nil}
        it {response.should render_template(:show)}
        it {flash.should be_empty}
        it "assigns kenshi to kenshi1" do
          assigns(:kenshi).should eql kenshi1
        end
      end

      describe "when GET to :new with user_id: basic_user.to_param," do
        before :each do
          get :new, user_id: basic_user.to_param, locale: I18n.locale
        end
        it {
          assigns(:current_user).should == basic_user
        }
        it {response.should be_success}
        it {assigns(:kenshi).should_not be_nil}
        it {response.should render_template(:new)}
        it {flash.should be_empty}
      end

      describe "when GET to :new without user_id param," do
        before :each do
          get :new, locale: I18n.locale
        end
        it {expect(response).to redirect_to new_user_kenshi_path(basic_user)}
      end

      describe "when POST to :create with valid data," do
        before :each do
          post :create, kenshi: valid_params, user_id: basic_user.to_param, locale: I18n.locale
        end

        it {assigns(:kenshi).should be_an_instance_of Kendocup::Kenshi}
        it {assigns(:kenshi).should be_valid_verbose}
        it {expect(response).to redirect_to(user_path(basic_user)) }
        it {flash[:notice].should =~ /Kenshi successfully registered/}
        it {assigns(:kenshi).user.should eql basic_user}
      end

      describe "when POST to :create with invalid data," do
        before :each do
          post :create, kenshi: {last_name: ""}, user_id: basic_user.to_param, locale: I18n.locale
        end

        it {assigns(:kenshi).should_not be_nil}
        it {assigns(:kenshi).should be_an_instance_of Kendocup::Kenshi}
        it {assigns(:kenshi).should_not be_valid_verbose}
        it {response.should render_template(:new)}
        it {flash.now[:alert].should =~ /Kenshi not registered/}
      end

      describe "on GET to :edit with :id = basic_user_kenshi.to_param," do
        before { get :edit, id: basic_user_kenshi.to_param }
        it{response.should be_success}
        it{assigns(:kenshi).should == basic_user_kenshi}
        it {response.should render_template(:edit)}
      end

      describe "on GET to :edit with :id = kenshi1.to_param," do
        before :each do
          get :edit, id: kenshi1.to_param, locale: I18n.locale
        end
        should_not_be_authorized
      end

      describe "on PUT to :update with :id = basic_user_kenshi.to_param and valid data"  do
        before {put :update, id: basic_user_kenshi.to_param, kenshi: {last_name: "alaNma2"}}

        it {assigns(:kenshi).should eql basic_user_kenshi}
        it {expect(response).to redirect_to(user_path(basic_user_kenshi.user))}
        it {flash[:notice].should =~ /Registration successfully updated/}
        it {basic_user_kenshi.reload.last_name.should eql 'alaNma2'}
      end

      describe "on PUT to :update with :id = basic_user_kenshi.to_param and invalid data," do
        before :each do
          put :update, id: basic_user_kenshi.to_param, kenshi: {last_name: ""}, locale: I18n.locale
        end

        it {assigns(:kenshi).should eql basic_user_kenshi}
        it {response.should render_template(:edit)}
        it {flash[:alert].should =~ /Kenshi not updated/}
      end

      describe "on PUT to :update with :id = kenshi1.to_param and valid data," do
        before :each do
          put :update, id: kenshi1.to_param, kenshi: {last_name: "alaNma2"}, locale: I18n.locale
        end
        should_not_be_authorized
      end

      describe "on DELETE to :destroy with :id = basic_user_kenshi.to_param," do
        before :each do
          basic_user_kenshi.save
          @kenshi_count = Kendocup::Kenshi.count
          delete :destroy, id: basic_user_kenshi.to_param
        end

        it {assigns(:kenshi).should == basic_user_kenshi}
        it "change Kendocup::Kenshi.count by -1" do
          (@kenshi_count - Kendocup::Kenshi.count).should eql 1
        end
        it {should set_flash.to('Kenshi successfully destroyed')}
        it {expect(response).to redirect_to(user_path(basic_user))}
      end

      describe "on DELETE to :destroy with :id = kenshi1.to_param," do
        before :each do
          delete :destroy, id: kenshi1.to_param, locale: I18n.locale
        end
        should_not_be_authorized
      end

      context "when deadline is passed" do
        before {
          Timecop.travel(cup.deadline+5.minutes)
        }

        describe "when GET to :new with user_id: basic_user.to_param," do
          before :each do
            get :new, user_id: basic_user.to_param, locale: I18n.locale
          end
          deadline_passed
        end

        describe "on GET to :edit with :id = basic_user_kenshi.to_param," do
          before { get :edit, id: basic_user_kenshi.to_param }
          deadline_passed
        end

        describe "on PUT to :update with :id = basic_user_kenshi.to_param and valid data,"  do
          before {put :update, id: basic_user_kenshi.to_param, kenshi: {last_name: "alaNma2"}, locale: I18n.locale}
          deadline_passed
        end

        describe "when POST to :create with valid data," do
          before :each do
            post :create, kenshi: valid_params, locale: I18n.locale
          end
          deadline_passed
        end

        describe "on DELETE to :destroy with :id = basic_user_kenshi.to_param," do
          before :each do
            basic_user_kenshi.save
            @kenshi_count = Kendocup::Kenshi.count
            delete :destroy, id: basic_user_kenshi.to_param, locale: I18n.locale
          end
          deadline_passed
        end
      end
    end
  end
end
