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
          delete cup_participation_path(cup, participation)
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
          expect { delete_request }.to change(Participation, :count).by(-1)
          expect(assigns(:participation)).to eql participation
          expect(flash[:notice]).to match "Participation successfully destroyed"
          expect(response).to redirect_to(cup_user_path(cup))
        end
      end

      describe "on DELETE to :destroy with a participation that does not belong to the user" do
        let(:another_participation) { create :participation }

        before {
          delete cup_participation_path(cup, another_participation)
        }

        it { should_not_be_authorized }
      end
    end
  end
end
