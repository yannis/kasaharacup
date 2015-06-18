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
          delete :destroy, id: participation.to_param, cup_id: cup.to_param, locale: I18n.locale
        }
        should_be_asked_to_sign_in
      end
    end

    describe "when logged in as basic user" do
      before{ sign_in user }

      describe "on DELETE to :destroy with a participation that does not belong to the user" do
        let!(:participation_count) {Kendocup::Participation.count}
        before {
          delete :destroy, id: participation.to_param, cup_id: cup.to_param, locale: I18n.locale
        }
        it {expect(assigns(:participation)).to eql participation}
        it { expect(participation_count - Kendocup::Participation.count).to eql 1}
        it {expect(flash[:notice]).to match 'Participation successfully destroyed'}
        it {expect(response).to redirect_to(root_path)}
      end

      describe "on DELETE to :destroy with a participation that does not belong to the user" do
        let(:another_participation) { create :kendocup_participation }
        before {
          delete :destroy, id: another_participation.to_param, cup_id: cup.to_param, locale: I18n.locale
        }
        should_not_be_authorized
      end
    end
  end
end
