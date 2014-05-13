# encoding: utf-8
require 'spec_helper'

describe ParticipationsController do

  describe "with a participation in the database," do

    let(:cup) {create :cup, start_on: Date.current+3.weeks}
    let(:category) {create :individual_category, cup: cup}
    let(:user) { create :user }
    let(:kenshi) {create :kenshi, user: user, cup: cup}
    let!(:participation) { create :participation, category: category, kenshi: kenshi }

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
        let!(:participation_count) {Participation.count}
        before {
          delete :destroy, id: participation.to_param
        }
        it {assigns(:participation).should == participation}
        it "change Participation.count by -1" do
          (participation_count - Participation.count).should eql 1
        end
        it {should set_the_flash.to('Participation détruite avec succès')}
        it {response.should redirect_to(user_path(user))}
      end

      describe "on DELETE to :destroy with a participation that does not belong to the user" do
        let(:another_participation) { create :participation }
        before {
          delete :destroy, id: another_participation.to_param
        }
        should_not_be_authorized
      end
    end
  end
end
