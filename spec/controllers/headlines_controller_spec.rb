require 'spec_helper'

describe HeadlinesController do

  let!(:cup){create :cup, start_on: Date.current+20.days}

  describe "with 3 headlines in the database," do
    let(:user) {create :user}
    let(:user2) {create :user, :admin => true}
    let(:headline1) {create :headline, :title_fr => 'headline1', cup: cup}
    let(:headline2) {create :headline, :title_fr => 'headline2', cup: cup}
    let(:headline3) {create :headline, :title_fr => 'headline3', cup: cup}

    context "when not logged in," do

      describe "on GET to :index without param,"do
        before do
          get :index, cup_id: cup.to_param
        end

        it {response.should be_success}
        it {assigns(:headlines).should_not be_nil}
        it {response.should render_template(:index)}
        it {expect(assigns(:headlines)).to eq [headline1, headline2, headline3]}
        it {flash.should be_empty}
      end

      describe "when GET to :show for headline1.id," do
        before :each do
          get :show, id: headline1.to_param
        end

        it {response.should be_success}
        it {assigns(:headline).should == headline1}
        it {response.should render_template(:show)}
        it {flash.should be_empty}
      end
    end

    describe "when logged in as basic" do
      let(:basic_user){ create :user }
      before{ sign_in basic_user }

      describe "on GET to :index" do
        before :each do
          get :index, cup_id: cup.to_param
        end

        it{ basic_user.should be_valid_verbose}
        it {assigns(:headlines).should_not be_nil}
        it {response.should render_template(:index)}
        it {assigns(:headlines).should =~ [headline1, headline2, headline3]}
        it {flash.should be_empty}
      end

      describe "when GET to :show for headline1.id," do
        before :each do
          get :show, id: headline1.to_param
        end

        it {response.should be_success}
        it {assigns(:headline).should == headline1}
        it {response.should render_template(:show)}
        it {flash.should be_empty}
      end
    end
  end
end
