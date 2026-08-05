# frozen_string_literal: true

require "rails_helper"

RSpec.describe CupsController do
  let!(:cup1) { create(:cup, events: create_list(:event, 1)) }
  let!(:cup2) { create(:cup) }
  let!(:cup3) { create(:cup) }

  context "when not logged in" do
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

    describe "when GET to :show for a cup with products" do
      let!(:cup4) { create(:cup, events: create_list(:event, 1)) }
      let!(:product) { create(:product, cup: cup4) }

      before { get(cup_path(cup4)) }

      it "states that bank transfer fees are at the sender's charge" do
        expect(response.body).to include(CGI.escapeHTML(I18n.t("cups.show.fees.prepayment_transfer_fees")))
      end
    end
  end
end
