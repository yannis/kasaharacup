require 'rails_helper'
RSpec.describe PurchasesController, type: :controller do

  describe "with a purchase in the database," do

    let(:cup) {create :kendocup_cup, start_on: Date.today+3.weeks}
    let(:product) {create :kendocup_product, cup: cup}
    let(:user) { create :kendocup_user }
    let(:kenshi) {create :kendocup_kenshi, female: false, user: user, cup: cup}
    let!(:purchase) { create :kendocup_purchase, product: product, kenshi: kenshi }

    it {expect(purchase).to be_valid_verbose}


    context "when not logged in," do
      describe "on DELETE to :destroy the purchase " do
        before {
          delete :destroy, id: purchase.to_param, locale: I18n.locale, cup_id: cup.to_param
        }
        should_be_asked_to_sign_in
      end
    end

    describe "when logged in as basic user" do
      before{ sign_in user }

      describe "on DELETE to :destroy with a purchase that does not belong to the user" do
        let!(:purchase_count) {Kendocup::Purchase.count}
        before {
          delete :destroy, id: purchase.to_param, locale: I18n.locale, cup_id: cup.to_param
        }
        it {expect(assigns(:purchase)).to eql purchase}
        it {expect((purchase_count - Kendocup::Purchase.count)).to eql 1}
        it {expect(flash.notice).to eql 'Extra successfully removed'}
        it {expect(response).to redirect_to(root_path)}
      end

      describe "on DELETE to :destroy with a purchase that does not belong to the user" do
        let(:another_purchase) { create :kendocup_purchase }
        before {
          delete :destroy, id: another_purchase.to_param, locale: I18n.locale, cup_id: cup.to_param
        }
        should_not_be_authorized
      end
    end
  end
end
