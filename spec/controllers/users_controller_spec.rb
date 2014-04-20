require 'spec_helper'

describe UsersController do
  let(:user) {create :user}
  let(:basic_user) {create :user}
  let(:admin_user) {create :user, admin: true}

  def valid_attributes
    {last_name: "a_last_name#{rand(1..1000)}", first_name: 'a_first_name', email: "anemail@address.com", password: 'jkasdkjd', password_confirmation: 'jkasdkjd'}
  end

  USER_CONT_METHODS = ["get :index, locale: I18n.locale", "get :show, id: user.to_param, locale: I18n.locale", "get :new, locale: I18n.locale", "get :edit, id: user.to_param, locale: I18n.locale", "post :create, user: valid_attributes, locale: I18n.locale", "put :update, id: user.to_param, user: {last_name: 'just updated user'}, locale: I18n.locale", "delete :destroy, id: user.to_param, locale: I18n.locale"]

  describe "not signed in" do
    USER_CONT_METHODS.each do |m|
      describe "on #{m}" do
        before :each do
          I18n.locale = 'fr'
          eval(m)
        end
        should_be_asked_to_sign_in
      end
    end
  end

  BASICUSER_CONT_METHODS = ["get :show, id: user.to_param, locale: I18n.locale", "get :new, locale: I18n.locale", "get :edit, id: user.to_param, locale: I18n.locale", "post :create, user: valid_attributes, locale: I18n.locale", "put :update, id: user.to_param, user: {last_name: 'just updated user'}, locale: I18n.locale", "delete :destroy, id: user.to_param, locale: I18n.locale"]

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
      before {get :index, locale: I18n.locale}
      it {response.should be_success}
      it {response.should render_template 'index'}
      it {assigns(:users).should =~ [basic_user]}
    end

    describe "GET show with self user_id" do
      before {get :show, id: basic_user.to_param, locale: I18n.locale}
      it {response.should be_success}
      it {response.should render_template 'show'}
      it {assigns(:user).should eq(basic_user) }
    end

    describe "GET edit with self user_id" do
      before {get :edit, id: basic_user.to_param, locale: I18n.locale}
      it {response.should be_success}
      it {response.should render_template 'edit'}
      it {assigns(:user).should eq(basic_user) }
    end

    describe "PUT update with self user_id" do
      before {put :update, id: basic_user.to_param, user: {last_name: 'just updated user'}, locale: I18n.locale}
      it{response.should redirect_to(user_path(basic_user.reload, locale: I18n.locale))}
      it {assigns(:user).should eq(basic_user) }
    end

    describe "DELETE destroy with self user_id" do
      it "destroys the requested user" do
        expect {
          delete :destroy, id: basic_user.to_param, locale: I18n.locale
        }.to change(User, :count).by(-1)
      end

      it "redirects to the users list" do
        delete :destroy, id: basic_user.to_param, locale: I18n.locale
        response.should redirect_to(root_path)
      end
    end
  end

  context "When logged in as admin" do

    before {sign_in admin_user}

    describe "GET index" do
      before {get :index, locale: I18n.locale}
      it{ response.should be_success}
      it{response.should render_template 'index'}
      it {assigns(:users).should eq User.all}
    end

    describe "GET show with self user_id" do
      before{get :show, id: admin_user.to_param, locale: I18n.locale}
      it{assigns(:user).should eq(admin_user)}
      it{response.should be_success}
      it{response.should render_template 'show'}
    end

    describe "GET show with another user_id" do
      before{get :show, id: user.to_param, locale: I18n.locale}
      it{assigns(:user).should eq(user)}
      it{response.should be_success}
      it{response.should render_template 'show'}
    end

    describe "GET new" do
      before{get :new, locale: I18n.locale}
      it {assigns(:user).should be_a_new(User)}
      it{response.should be_success}
      it{response.should render_template 'new'}
    end

    describe "GET edit with self user_id" do
      before {get :edit, id: admin_user.to_param, locale: I18n.locale}
      it {assigns(:user).should eq admin_user}
      it{response.should be_success}
      it{response.should render_template 'edit'}
    end

    describe "GET edit with another user_id" do
      before {get :edit, id: user.to_param, locale: I18n.locale}
      it {assigns(:user).should eq user}
      it{response.should be_success}
      it{response.should render_template 'edit'}
    end

    describe "POST create"  do
      describe "with valid params" do
        it "creates a new User" do
          expect {
            post :create, user: valid_attributes, locale: I18n.locale
          }.to change(User, :count).by(1)
        end

        it "should be valid" do
          post :create, user: valid_attributes, locale: I18n.locale
          assigns(:user).should be_valid_verbose
        end

        it "assigns a newly created user as user" do
          post :create, user: valid_attributes, locale: I18n.locale
          assigns(:user).should be_a(User)
          assigns(:user).should be_persisted
        end

        it "redirects to the created user" do
          post :create, user: valid_attributes, locale: I18n.locale
          response.should redirect_to(new_user_enrollment_path(User.last, locale: I18n.locale))
        end

        # it "sends a notifictaion" do
        #   # expect
        #   # UserMailer.should_receive(:signup_notification).with('a name for that new user', 'anemail@address.com')
        #   ActionMailer::Base.deliveries.last.subject.should eql "Instructions de confirmation"
        #   ActionMailer::Base.deliveries.last.date.to_s(:db).should eql Time.now.to_s(:db)
        #   # when
        #   post :create, user: valid_attributes, locale: I18n.locale
        # end
      end

      describe "with invalid params" do
        it "assigns a newly created but unsaved user as user" do
          # Trigger the behavior that occurs when invalid params are submitted
          User.any_instance.stub(:save).and_return(false)
          post :create, user: {}, locale: I18n.locale
          assigns(:user).should be_a_new(User)
        end

        it "re-renders the 'new' template" do
          # Trigger the behavior that occurs when invalid params are submitted
          User.any_instance.stub(:save).and_return(false)
          post :create, user: {}, locale: I18n.locale
          response.should render_template("new")
        end
      end
    end

    describe "PUT update" do
      describe "with valid params" do
        it "updates the requested user" do
          User.any_instance.should_receive(:update_attributes).with({"password_confirmation"=>nil, "these"=>"params", "password"=>nil})
          put :update, id: user.to_param, user: {"password_confirmation"=>nil, "these"=>"params", "password"=>nil}, locale: I18n.locale
        end

        it "assigns the requested user as user" do
          put :update, id: user.to_param, user: valid_attributes, locale: I18n.locale
          assigns(:user).should eq(user)
        end

        it "redirects to the user" do
          put :update, id: user.to_param, user: valid_attributes, locale: I18n.locale
          response.should redirect_to(user_path(user.reload, locale: I18n.locale))
        end
      end

      describe "with invalid params" do
        it "assigns the user as user" do
          # Trigger the behavior that occurs when invalid params are submitted
          User.any_instance.stub(:save).and_return(false)
          put :update, id: user.to_param, user: {last_name: ''}, locale: I18n.locale
          assigns(:user).should eq(user)
        end

        it "re-renders the 'edit' template" do
          # Trigger the behavior that occurs when invalid params are submitted
          User.any_instance.stub(:save).and_return(false)
          put :update, id: user.to_param, user: {last_name: ''}, locale: I18n.locale
          response.should render_template("edit")
        end
      end
    end

    describe "DELETE destroy with self user_id" do
      it "destroys the requested user" do
        expect {
          delete :destroy, id: admin_user.to_param, locale: I18n.locale
        }.to change(User, :count).by(-1)
      end

      it "redirects to the users list" do
        delete :destroy, id: admin_user.to_param, locale: I18n.locale
        response.should redirect_to(users_path(locale: I18n.locale))
      end
    end

    describe "DELETE destroy with another user_id" do
      let!(:another_user){create :user}
      it "destroys the requested user" do
        expect {
          delete :destroy, id: another_user.to_param, locale: I18n.locale
        }.to change(User, :count).by(-1)
      end

      it "redirects to the users list" do
        delete :destroy, id: another_user.to_param, locale: I18n.locale
        response.should redirect_to(users_path(locale: I18n.locale))
      end
    end
  end
end
