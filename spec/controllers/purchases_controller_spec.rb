# encoding: utf-8
require 'spec_helper'

describe PurchasesController do

  describe "with a purchase in the database," do

    let(:cup) {create :cup, start_on: Date.today+3.weeks}
    let(:product) {create :product, cup: cup}
    let(:user) { create :user }
    let(:kenshi) {create :kenshi, female: false, user: user, cup: cup}
    let!(:purchase) { create :purchase, product: product, kenshi: kenshi }

    it {expect(purchase).to be_valid_verbose}


    context "when not logged in," do
      describe "on DELETE to :destroy the purchase " do
        before {
          delete :destroy, id: purchase.to_param
        }
        should_be_asked_to_sign_in
      end
    end

    describe "when logged in as basic user" do
      before{ sign_in user }

      describe "on DELETE to :destroy with a purchase that does not belong to the user" do
        let!(:purchase_count) {Purchase.count}
        before {
          delete :destroy, id: purchase.to_param
        }
        it {assigns(:purchase).should == purchase}
        it "change Purchase.count by -1" do
          (purchase_count - Purchase.count).should eql 1
        end
        it {should set_the_flash.to('Extra détruit avec succès')}
        it {response.should redirect_to(user_path(user))}
      end

      describe "on DELETE to :destroy with a purchase that does not belong to the user" do
        let(:another_purchase) { create :purchase }
        before {
          delete :destroy, id: another_purchase.to_param
        }
        should_not_be_authorized
      end
    end
  end
end
