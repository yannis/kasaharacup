# frozen_string_literal: true

require "rails_helper"

RSpec.describe CupsController do
  let!(:cup1) { create(:cup, start_on: Date.current + 1.month, events: [create(:event)]) }
  let!(:cup2) { create(:cup, start_on: Date.current - 2.years) }
  let!(:cup3) { create(:cup, start_on: Date.current + 1.year) }

  context "When not logged in" do
    describe "when GET to :show for cup1" do
      before { get(cup_path(cup1)) }

      it do
        expect(response).to have_http_status(:success)
        expect(assigns(:cup)).not_to be_nil
        expect(assigns(:cup)).to eql cup1
        expect(response).to render_template(:show)
        expect(flash).to be_empty
      end
    end
  end
end
