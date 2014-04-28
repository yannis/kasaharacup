# encoding: utf-8
require 'spec_helper'

describe KenshisController do

  def valid_params
    {last_name: "a_last_name", first_name: "a_first_name", grade: '1Dan', club: "a_club", cup: cup, dob: 20.years.ago}
  end

  before {
    Timecop.travel(cup.deadline-5.days)
  }

  describe "with 3 kenshis in the database," do

    let!(:cup) {create :cup, start_on: Date.current+3.weeks}
    let(:user) {create :user}
    let(:user2) {create :user, admin: true}
    let(:kenshi1) {create :kenshi, last_name: 'kenshi1', user_id: user.to_param, cup: cup}
    let(:kenshi2) {create :kenshi, last_name: 'kenshi2', user_id: user2.to_param, cup: cup}
    let(:kenshi3) {create :kenshi, last_name: 'kenshi3', user_id: user.to_param, cup: cup}

    KENSHI_CONT_METHODS = ["get :new", "post :create, kenshi: {last_name: 'just created kenshi'}", "put :update, id: kenshi1.to_param, kenshi: {last_name: 'just updated kenshi'}", "delete :destroy, id: kenshi1.to_param"]

    context "when not logged in," do

      describe "on GET to :index without param," do
        before do
          get :index
        end

        it {response.should be_success}
        it {assigns(:kenshis).should_not be_nil}
        it {response.should render_template(:index)}
        it {assigns(:kenshis).should =~ [kenshi1, kenshi2, kenshi3]}
        it {flash.should be_empty}
      end

      # describe "on GET to :index with format csv" do
      #   before :each do
      #     get :index, format: :csv
      #   end

      #   it { response.header['Content-Type'].should match 'text/csv' }
      # end

      describe "on GET to :index with param :user_id" do
        before :each do
          get :index, user_id: user.to_param
        end

        it {response.should redirect_to kenshis_path}
        it {flash.should be_empty}
      end

      describe "when GET to :show for kenshi1.id," do
        before :each do
          get :show, id: kenshi1.to_param
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
          # it {response.should redirect_to(new_user_session_path)}
          # it {flash[:alert].should eq I18n.t("devise.failure.unauthenticated")}
        end
      end
    end

    describe "when logged in" do
      let(:basic_user){ create :user }
      let(:basic_user_kenshi){create :kenshi, user_id: basic_user.id}
      before{ sign_in basic_user }

      describe "on GET to :index without param," do
        before :each do
          get :index
        end

        it {assigns(:kenshis).should_not be_nil}
        it {response.should render_template(:index)}
        it {assigns(:kenshis).should =~ [kenshi1, kenshi2, kenshi3]}
        it {flash.should be_empty}
      end

      describe "when GET to :show for kenshi1.id," do
        before :each do
          get :show, id: kenshi1.to_param
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
          get :new, user_id: basic_user.to_param
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
          get :new
        end
        it{response.should redirect_to new_user_kenshi_path(basic_user)}
      end

      describe "when POST to :create with valid data," do
        before :each do
          post :create, kenshi: valid_params
        end

        it {assigns(:kenshi).should be_an_instance_of Kenshi}
        it {assigns(:kenshi).should be_valid_verbose}
        it {response.should redirect_to(user_path(basic_user)) }
        it {flash[:notice].should =~ /Kenshi inscrit avec succès/}
        it {assigns(:kenshi).user.should eql basic_user}
      end

      describe "when POST to :create with invalid data," do
        before :each do
          post :create, kenshi: {last_name: ""}
        end

        it {assigns(:kenshi).should_not be_nil}
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
          get :edit, id: kenshi1.to_param
        end
        should_not_be_authorized
      end

      describe "on PUT to :update with :id = basic_user_kenshi.to_param and valid data"  do
        before {put :update, id: basic_user_kenshi.to_param, kenshi: {last_name: "alaNma2"}}

        it {assigns(:kenshi).should eql basic_user_kenshi}
        it {response.should redirect_to(user_path(basic_user_kenshi.user))}
        it {flash[:notice].should =~ /Inscription modifiée avec succès/}
        it {basic_user_kenshi.reload.last_name.should eql 'alaNma2'}
      end

      describe "on PUT to :update with :id = basic_user_kenshi.to_param and invalid data," do
        before :each do
          put :update, id: basic_user_kenshi.to_param, kenshi: {last_name: ""}
        end

        it {assigns(:kenshi).should eql basic_user_kenshi}
        it {response.should render_template(:edit)}
        it {flash[:alert].should =~ /Kenshi not updated/}
      end

      describe "on PUT to :update with :id = kenshi1.to_param and valid data," do
        before :each do
          put :update, id: kenshi1.to_param, kenshi: {last_name: "alaNma2"}
        end
        should_not_be_authorized
      end

      describe "on DELETE to :destroy with :id = basic_user_kenshi.to_param," do
        before :each do
          basic_user_kenshi.save
          @kenshi_count = Kenshi.count
          delete :destroy, id: basic_user_kenshi.to_param
        end

        it {assigns(:kenshi).should == basic_user_kenshi}
        it "change Kenshi.count by -1" do
          (@kenshi_count - Kenshi.count).should eql 1
        end
        it {should set_the_flash.to('Kenshi détruit avec succès')}
        it {response.should redirect_to(user_path(basic_user))}
      end

      describe "on DELETE to :destroy with :id = kenshi1.to_param," do
        before :each do
          delete :destroy, id: kenshi1.to_param
        end
        should_not_be_authorized
      end

      context "when deadline is passed" do
        before {
          Timecop.travel(cup.deadline+5.minutes)
        }

        describe "when GET to :new with user_id: basic_user.to_param," do
          before :each do
            get :new, user_id: basic_user.to_param
          end
          deadline_passed
        end

        describe "on GET to :edit with :id = basic_user_kenshi.to_param," do
          before { get :edit, id: basic_user_kenshi.to_param }
          deadline_passed
        end

        describe "on PUT to :update with :id = basic_user_kenshi.to_param and valid data,"  do
          before {put :update, id: basic_user_kenshi.to_param, kenshi: {last_name: "alaNma2"}}
          deadline_passed
        end

        describe "when POST to :create with valid data," do
          before :each do
            post :create, kenshi: valid_params
          end
          deadline_passed
        end

        describe "on DELETE to :destroy with :id = basic_user_kenshi.to_param," do
          before :each do
            basic_user_kenshi.save
            @kenshi_count = Kenshi.count
            delete :destroy, id: basic_user_kenshi.to_param
          end
          deadline_passed
        end
      end
    end
  end
end
