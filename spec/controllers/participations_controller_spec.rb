# frozen_string_literal: true

require "rails_helper"
RSpec.describe ParticipationsController do
  describe "with a participation in the database," do
    let(:cup) { create :cup, start_on: Date.current + 3.weeks }
    let(:category) { create :individual_category, cup: cup }
    let(:user) { create :user }
    let(:kenshi) { create :kenshi, user: user, cup: cup }
    let!(:participation) { create :participation, category: category, kenshi: kenshi }

    it { expect(participation).to be_valid_verbose }

    context "when not logged in," do
      describe "on DELETE to :destroy the participation" do
        before {
          delete :destroy, params: {id: participation.to_param, cup_id: cup.to_param, locale: I18n.locale}
        }

        it { should_be_asked_to_sign_in }
      end
    end

    describe "when logged in as basic user" do
      before { sign_in user }

      describe "on DELETE to :destroy with a participation that does belong to the user" do
        let(:delete_request) do
          delete cup_participation_path(cup, participation)
        end

        it do
          delete_request
          expect(assigns(:participation)).to eql participation
        end

        it { expect { delete_request }.to change(Participation, :count).by(-1) }
        it { expect(flash[:notice]).to match "Participation successfully destroyed" }
        it { expect(response).to redirect_to(root_path) }
      end

      describe "on DELETE to :destroy with a participation that does not belong to the user" do
        let(:another_participation) { create :participation }

        before {
          delete cup_participation_path(cup, another_participation)
          # delete :destroy, params: {id: another_participation.to_param, cup_id: cup.to_param, locale: I18n.locale}
        }

        it { should_not_be_authorized }
      end
    end
  end
end
