require 'rails_helper'

RSpec.describe UsersController, type: :controller do

  let!(:cup) {create :kendocup_cup, start_on: Date.current+2.days}
  let(:user) {create :kendocup_user}
  let(:basic_user) {create :kendocup_user}
  let(:admin_user) {create :kendocup_user, admin: true}

  def valid_attributes
    {last_name: "a_last_name#{rand(1..1000)}", first_name: 'a_first_name', email: "anemail@address.com", password: 'jkasdkjd', password_confirmation: 'jkasdkjd'}
  end

  USER_CONT_METHODS = ["get :show, id: user.to_param, locale: I18n.locale, cup_id: cup.to_param"]
  # , "delete :destroy, id: user.to_param"

  describe "not signed in" do
    USER_CONT_METHODS.each do |m|
      describe "on #{m}" do
        before :each do
          eval(m)
        end
        should_be_asked_to_sign_in
      end
    end
  end

  BASICUSER_CONT_METHODS = ["get :show, id: user.to_param, locale: I18n.locale, cup_id: cup.to_param"]
  # , "delete :destroy, id: user.to_param"

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

    # describe "GET index" do
    #   before {get :index}
    #   it {expect(response).to be_success}
    #   it {expect(response).to render_template 'index'}
    #   it {assigns(:users).should =~ [basic_user]}
    # end

    describe "GET show with self user_id" do
      before {get :show, id: basic_user.to_param, locale: I18n.locale, cup_id: cup.to_param}
      it {expect(response).to be_success}
      it {expect(response).to render_template 'show'}
      it {expect(assigns(:user)).to eq(basic_user) }
    end

    describe "GET edit with self user_id" do
      before {get :edit, id: basic_user.to_param, locale: I18n.locale, cup_id: cup.to_param}
      it {expect(response).to be_success}
      it {expect(response).to render_template 'edit'}
      it {expect(assigns(:user)).to eq(basic_user) }
    end

    describe "PUT update with self user_id" do
      before {put :update, id: basic_user.to_param, user: {last_name: 'just updated user'}, locale: I18n.locale, cup_id: cup.to_param}
      it{expect(response).to redirect_to(cup_user_path(cup, basic_user.reload))}
      it {expect(assigns(:user)).to eq(basic_user) }
    end

    describe "DELETE destroy with self user_id" do
      it "destroys the requested user" do
        expect {
          delete :destroy, id: basic_user.to_param, locale: I18n.locale, cup_id: cup.to_param
        }.to change(User, :count).by(-1)
      end

      it "redirects to the users list" do
        delete :destroy, id: basic_user.to_param, locale: I18n.locale, cup_id: cup.to_param
        expect(response).to redirect_to(root_path)
      end
    end
  end

  context "When logged in as admin" do

    before {sign_in admin_user}

    # describe "GET index" do
    #   before {get :index}
    #   it{ expect(response).to be_success}
    #   it{expect(response).to render_template 'index'}
    #   it {expect(assigns(:users)).to eq User.all.to_a}
    # end

    describe "GET show with self user_id" do
      before{get :show, id: admin_user.to_param, locale: I18n.locale, cup_id: cup.to_param}
      it{expect(assigns(:user)).to eq(admin_user)}
      it{expect(response).to be_success}
      it{expect(response).to render_template 'show'}
    end

    describe "GET show with another user_id" do
      before{get :show, id: user.to_param, locale: I18n.locale, cup_id: cup.to_param}
      it{expect(assigns(:user)).to eq(user)}
      it{expect(response).to be_success}
      it{expect(response).to render_template 'show'}
    end

    describe "GET edit with self user_id" do
      before {get :edit, id: admin_user.to_param, locale: I18n.locale, cup_id: cup.to_param}
      it {expect(assigns(:user)).to eq admin_user}
      it{expect(response).to be_success}
      it{expect(response).to render_template 'edit'}
    end

    describe "GET edit with another user_id" do
      before {get :edit, id: user.to_param, locale: I18n.locale, cup_id: cup.to_param}
      it {expect(assigns(:user)).to eq user}
      it{expect(response).to be_success}
      it{expect(response).to render_template 'edit'}
    end

    describe "PUT update" do
      describe "with valid params" do
        # it "updates the requested user" do
        #   User.any_instance.should_receive(:update_with_password).with({"password_confirmation"=>nil, "these"=>"params", "password"=>nil})
        #   put :update, id: user.to_param, user: {"password_confirmation"=>nil, "these"=>"params", "password"=>nil}
        # end

        it "assigns the requested user as user" do
          put :update, id: user.to_param, user: valid_attributes, locale: I18n.locale, cup_id: cup.to_param
          expect(assigns(:user)).to eq(user)
        end

        it "redirects to the user" do
          put :update, id: user.to_param, user: valid_attributes, locale: I18n.locale, cup_id: cup.to_param
          expect(response).to render_template "devise/mailer/confirmation_instructions"
        end
      end

      describe "with invalid params" do
        it "assigns the user as user" do
          # Trigger the behavior that occurs when invalid params are submitted
          # User.any_instance.stub(:save).and_return(false)
          put :update, id: user.to_param, user: {last_name: ''}, locale: I18n.locale, cup_id: cup.to_param
          expect(assigns(:user)).to eq(user)
        end

        it "re-renders the 'edit' template" do
          # Trigger the behavior that occurs when invalid params are submitted
          # User.any_instance.stub(:save).and_return(false)
          put :update, id: user.to_param, user: {last_name: ''}, locale: I18n.locale, cup_id: cup.to_param
          expect(response).to render_template "users/edit"
        end
      end
    end

    describe "DELETE destroy with self user_id" do
      it "destroys the requested user" do
        expect {
          delete :destroy, id: admin_user.to_param, locale: I18n.locale, cup_id: cup.to_param
        }.to change(User, :count).by(-1)
      end

      it "redirects to the users list" do
        delete :destroy, id: admin_user.to_param, locale: I18n.locale, cup_id: cup.to_param
        expect(response).to redirect_to(cup_users_path(cup))
      end
    end

    describe "DELETE destroy with another user_id" do
      let!(:another_user){create :kendocup_user}
      it "destroys the requested user" do
        expect {
          delete :destroy, id: another_user.to_param, locale: I18n.locale, cup_id: cup.to_param
        }.to change(User, :count).by(-1)
      end

      it "redirects to the users list" do
        delete :destroy, id: another_user.to_param, locale: I18n.locale, cup_id: cup.to_param
        expect(response).to redirect_to(cup_users_path(cup))
      end
    end
  end
end
