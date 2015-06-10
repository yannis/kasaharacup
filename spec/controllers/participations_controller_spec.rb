require 'rails_helper'
RSpec.describe ParticipationsController, type: :controller do

  describe "with a participation in the database," do

    let(:cup) {create :kendocup_cup, start_on: Date.current+3.weeks}
    let(:category) {create :kendocup_individual_category, cup: cup}
    let(:user) { create :kendocup_user }
    let(:kenshi) {create :kendocup_kenshi, user: user, cup: cup}
    let!(:participation) { create :kendocup_participation, category: category, kenshi: kenshi }

    it {expect(participation).to be_valid_verbose}


    context "when not logged in," do
      describe "on DELETE to :destroy the participation " do
        before {
          delete :destroy, id: participation.to_param
        }
        should_be_asked_to_sign_in
      end
    end

    describe "when logged in as basic user" do
      before{ sign_in user }

      describe "on DELETE to :destroy with a participation that does not belong to the user" do
        let!(:participation_count) {Kendocup::Participation.count}
        before {
          delete :destroy, id: participation.to_param
        }
        it {assigns(:participation).should == participation}
        it "change Participation.count by -1" do
          (participation_count - Kendocup::Participation.count).should eql 1
        end
        it {should set_flash.to('Participation successfully destroyed')}
        it {expect(response).to redirect_to(user_path(user))}
      end

      describe "on DELETE to :destroy with a participation that does not belong to the user" do
        let(:another_participation) { create :kendocup_participation }
        before {
          delete :destroy, id: another_participation.to_param
        }
        should_not_be_authorized
      end
    end
  end
end
