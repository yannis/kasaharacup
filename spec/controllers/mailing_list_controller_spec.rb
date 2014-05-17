require 'spec_helper'

describe MailingListsController do

  context "when not signed in" do

    describe "GET 'new'" do
      it "returns http success" do
        get 'new', :locale => I18n.locale
        response.should be_success
      end
    end

    # describe "GET 'destroy'" do
    #   before {get 'destroy', :locale => I18n.locale}
    #   should_be_asked_to_sign_in
    # end
  end

  context "when signed in" do
    before {
      @request.env["devise.mapping"] = Devise.mappings[:user]
      @user = FactoryGirl.create :user
      # user.confirm!
      sign_in @user
    }

    describe "GET 'new'" do
      it "returns http success" do
        get 'new', :locale => I18n.locale
        response.should be_success
      end
    end

    # describe "GET 'destroy'" do
    #   it "returns http success" do
    #     get 'destroy', :locale => I18n.locale
    #     assigns(:current_user).should == @user

    #     MailingList.stub(:unsubscribe).and_return(true)
    #     response.should redirect_to root_path
    #   end
    # end
  end
end
