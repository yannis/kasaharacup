require 'spec_helper'

describe UsersController do
  let!(:cup) {create :cup, start_on: Date.current+2.days}
  let(:user) {create :user}
  let(:basic_user) {create :user}
  let(:admin_user) {create :user, admin: true}

  def valid_attributes
    {last_name: "a_last_name#{rand(1..1000)}", first_name: 'a_first_name', email: "anemail@address.com", password: 'jkasdkjd', password_confirmation: 'jkasdkjd'}
  end

  USER_CONT_METHODS = ["get :index", "get :show, id: user.to_param", "get :edit, id: user.to_param", "put :update, id: user.to_param, user: {last_name: 'just updated user'}", "delete :destroy, id: user.to_param"]

  describe "not signed in" do
    USER_CONT_METHODS.each do |m|
      describe "on #{m}" do
        before :each do
          I18n.locale = 'fr'
          eval(m)
        end
        # should_not_be_authorized
        should_be_asked_to_sign_in
      end
    end
  end

  BASICUSER_CONT_METHODS = ["get :show, id: user.to_param", "get :edit, id: user.to_param", "put :update, id: user.to_param, user: {last_name: 'just updated user'}", "delete :destroy, id: user.to_param"]

  describe "signed in as basic" do
    before {sign_in basic_user}
    BASICUSER_CONT_METHODS.each do |m|
      describe "on #{m}" do
        before :each do
          eval(m)
        end
        should_not_be_authorized
      end
    end

    describe "GET index" do
      before {get :index}
      it {response.should be_success}
      it {response.should render_template 'index'}
      it {assigns(:users).should =~ [basic_user]}
    end

    describe "GET show with self user_id" do
      before {get :show, id: basic_user.to_param}
      it {response.should be_success}
      it {response.should render_template 'show'}
      it {assigns(:user).should eq(basic_user) }
    end

    describe "GET edit with self user_id" do
      before {get :edit, id: basic_user.to_param}
      it {response.should be_success}
      it {response.should render_template 'edit'}
      it {assigns(:user).should eq(basic_user) }
    end

    describe "PUT update with self user_id" do
      before {put :update, id: basic_user.to_param, user: {last_name: 'just updated user'}}
      it{response.should redirect_to(user_path(basic_user.reload))}
      it {assigns(:user).should eq(basic_user) }
    end

    describe "DELETE destroy with self user_id" do
      it "destroys the requested user" do
        expect {
          delete :destroy, id: basic_user.to_param
        }.to change(User, :count).by(-1)
      end

      it "redirects to the users list" do
        delete :destroy, id: basic_user.to_param
        response.should redirect_to(root_path)
      end
    end
  end

  context "When logged in as admin" do

    before {sign_in admin_user}

    describe "GET index" do
      before {get :index}
      it{ response.should be_success}
      it{response.should render_template 'index'}
      it {expect(assigns(:users)).to eq User.all.to_a}
    end

    describe "GET show with self user_id" do
      before{get :show, id: admin_user.to_param}
      it{assigns(:user).should eq(admin_user)}
      it{response.should be_success}
      it{response.should render_template 'show'}
    end

    describe "GET show with another user_id" do
      before{get :show, id: user.to_param}
      it{assigns(:user).should eq(user)}
      it{response.should be_success}
      it{response.should render_template 'show'}
    end

    describe "GET edit with self user_id" do
      before {get :edit, id: admin_user.to_param}
      it {assigns(:user).should eq admin_user}
      it{response.should be_success}
      it{response.should render_template 'edit'}
    end

    describe "GET edit with another user_id" do
      before {get :edit, id: user.to_param}
      it {assigns(:user).should eq user}
      it{response.should be_success}
      it{response.should render_template 'edit'}
    end

    describe "PUT update" do
      describe "with valid params" do
        it "updates the requested user" do
          User.any_instance.should_receive(:update_attributes).with({"password_confirmation"=>nil, "these"=>"params", "password"=>nil})
          put :update, id: user.to_param, user: {"password_confirmation"=>nil, "these"=>"params", "password"=>nil}
        end

        it "assigns the requested user as user" do
          put :update, id: user.to_param, user: valid_attributes
          assigns(:user).should eq(user)
        end

        it "redirects to the user" do
          put :update, id: user.to_param, user: valid_attributes
          response.should redirect_to(user_path(user.reload))
        end
      end

      describe "with invalid params" do
        it "assigns the user as user" do
          # Trigger the behavior that occurs when invalid params are submitted
          User.any_instance.stub(:save).and_return(false)
          put :update, id: user.to_param, user: {last_name: ''}
          assigns(:user).should eq(user)
        end

        it "re-renders the 'edit' template" do
          # Trigger the behavior that occurs when invalid params are submitted
          User.any_instance.stub(:save).and_return(false)
          put :update, id: user.to_param, user: {last_name: ''}
          response.should render_template("edit")
        end
      end
    end

    describe "DELETE destroy with self user_id" do
      it "destroys the requested user" do
        expect {
          delete :destroy, id: admin_user.to_param
        }.to change(User, :count).by(-1)
      end

      it "redirects to the users list" do
        delete :destroy, id: admin_user.to_param
        response.should redirect_to(users_path(locale: I18n.locale))
      end
    end

    describe "DELETE destroy with another user_id" do
      let!(:another_user){create :user}
      it "destroys the requested user" do
        expect {
          delete :destroy, id: another_user.to_param
        }.to change(User, :count).by(-1)
      end

      it "redirects to the users list" do
        delete :destroy, id: another_user.to_param
        response.should redirect_to(users_path(locale: I18n.locale))
      end
    end
  end
end
