require 'spec_helper'

describe CupsController do

  let!(:cup1){create :cup, start_on: Date.current+2.months, events: [create(:event)] }
  let(:cup2){create :cup, start_on: Date.current-1.year}
  let(:cup3){create :cup, start_on: Date.cu}


  context "When not logged in" do
    describe "when GET to :show for cup1," do
      before {  get :show, year: Date.current.year }

      it {response.should be_success}
      it {assigns(:cup).should_not be_nil}
      it {response.should render_template(:show)}
      it {flash.should be_empty}
      it "assigns cup to cup1" do
        assigns(:cup).should eql cup1
      end
    end
  end

end


# # encoding: utf-8
# require 'spec_helper'

# describe Admin::TeamsController do

#   TEAM_ADMIN_VALID_PARAMS = {:name => "a team name"}

#   describe "with 3 teams in the database," do
#     let(:user) {FactoryGirl.create :user}
#     let(:user2) {FactoryGirl.create :user, :admin => true}
#     let(:team1) {FactoryGirl.create :team, :name => 'team1'}
#     let(:team2) {FactoryGirl.create :team, :name => 'team2'}
#     let(:team3) {FactoryGirl.create :team, :name => 'team3'}

#     ADMIN_TEAM_CONT_METHODS = ["get :new", "post :create, :team => {:name => 'just created team'}", "put :update, :id => team1.to_param, :team => {:name => 'just updated team'}", "delete :destroy, :id => team1.to_param"]

#     context "when not logged in," do
#       ADMIN_TEAM_CONT_METHODS.each do |action|

#         describe action do
#           before {eval(action)}
#           it {expect(response).to redirect_to root_path}
#         end

#       end
#     end

#     context "when logged in as basic" do
#       let(:basic_user){ FactoryGirl.create :user }
#       before{ sign_in basic_user }

#       ADMIN_TEAM_CONT_METHODS.each do |action|

#         describe action do
#           before {eval(action)}
#           it {expect(response).to redirect_to root_path}
#         end
#       end
#     end

#     context "when logged in as admin" do
#       let(:admin_user){ FactoryGirl.create :user, admin: true}
#       before{ sign_in admin_user }

#       describe "on GET to :index without param," do
#         before :each do
#           get :index
#         end

#         it {assigns(:teams).should_not be_nil}
#         it {response.should render_template(:index)}
#         it {assigns(:teams).should =~ [team1, team2, team3]}
#         it {flash.should be_empty}
#       end

#       describe "when GET to :show for team1.id," do
#         before :each do
#           get :show, :id => team1.to_param
#         end

#         it {response.should be_success}
#         it {assigns(:team).should_not be_nil}
#         it {response.should render_template(:show)}
#         it {flash.should be_empty}
#         it "assigns team to team1" do
#           assigns(:team).should eql team1
#         end
#       end

#       describe "when GET to :new," do
#         before :each do
#           get :new
#         end

#         it {response.should be_success}
#         it {assigns(:team).should_not be_nil}
#         it {response.should render_template(:new)}
#         it {flash.should be_empty}
#       end

#       describe "when POST to :create with valid data," do
#         before :each do
#           post :create, :team => TEAM_ADMIN_VALID_PARAMS
#         end

#         it {assigns(:team).should be_an_instance_of Team}
#         it {assigns(:team).should be_valid_verbose}
#         it {response.should redirect_to(admin_team_path(assigns(:team))) }
#         # it {flash.should =~ /Team was successfully created/}
#       end

#       describe "when POST to :create with invalid data," do
#         before :each do
#           post :create, :team => {:name => ""}
#         end

#         it {assigns(:team).should_not be_nil}
#         it {response.should render_template(:new)}
#         # it {flash.now[:alert].should =~ /Team not created/}
#       end

#       describe "on GET to :edit with :id = team1.to_param," do
#         before { get :edit, :id => team1.to_param }

#         it {response.should be_success}
#         it {assigns(:team).should == team1}
#         it {response.should render_template(:edit)}
#       end

#       describe "on PUT to :update with :id = team1.to_param and valid data," do
#         before {put :update, :id => team1.to_param, :team => {:name => "alaNma2"}}
#         it {assigns(:team).should == team1}
#         it {assigns(:team).should be_valid_verbose}
#         it {response.should redirect_to(admin_team_path(assigns(:team))) }
#       end

#       describe "on PUT to :update with :id = team1.to_param and invalid data," do
#         before :each do
#           put :update, :id => team1.to_param, :team => {:name => ""}
#         end
#         it {assigns(:team).should_not be_nil}
#         it {response.should render_template(:edit)}
#         # it {flash.now[:alert].should =~ /Team not created/}
#       end

#       describe "on DELETE to :destroy with :id = team1.to_param," do
#         before :each do
#           delete :destroy, :id => team1.to_param
#         end
#         it {assigns(:team).should == team1}
#         it {response.should redirect_to(admin_teams_path) }
#         # it {flash.should =~ /Team deleted/}
#       end
#     end
#   end
# end
