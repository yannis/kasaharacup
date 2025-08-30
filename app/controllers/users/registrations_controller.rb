# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    include HasLocale
    before_action :set_variables, only: [:new, :edit, :update, :create] # rubocop:disable Rails/LexicallyScopedActionFilter

    def new
      super
    end

    def create
      @user = User.new(my_sanitizer)
      if verify_recaptcha(model: @user) && @user.save
        sign_in @user
        redirect_to new_cup_user_kenshi_path(@current_cup, self: true)
      else
        render action: :new, status: :unprocessable_content
      end
    end

    def update
      @user = User.find(current_user.id)

      successfully_updated = if needs_password?(@user, params)
        @user.update_with_password(my_sanitizer)
        # @user.update_with_password(devise_parameter_sanitizer.for(:account_update))
        # Rails 3:  @user.update_with_password(params[:user])
      else
        # remove the virtual current_password attribute update_without_password
        # doesn't know how to ignore it
        params[:user].delete(:current_password)
        @user.update_without_password(my_sanitizer)
        # @user.update_with_password(devise_parameter_sanitizer.for(:account_update))
        # Rails 3: @user.update_without_password(params[:user])
      end

      if successfully_updated
        set_flash_message :notice, :updated
        # Log in the user bypassing validation in case his password changed
        sign_in @user, bypass: true
        redirect_to cup_user_path(@current_cup)
        # redirect_to after_update_path_for(@user)
      else
        render "edit", status: :unprocessable_content
      end
    end

    protected def my_sanitizer
      if current_user.try("admin?")
        params.expect(user: [:first_name, :last_name, :email, :dob, :female, :club_id, :club_name, :admin,
          :password, :password_confirmation, :current_password])
      else
        params.expect(user: [:first_name, :last_name, :email, :dob, :female, :club_id, :club_name, :password,
          :password_confirmation, :current_password])
      end
    end

    # check if we need password to update user data
    # ie if password or email was changed
    # extend this as needed
    private def needs_password?(user, params)
      user.email != params[:user][:email] ||
        params[:user][:password].present?
    end

    private def set_variables
      @club_names = Club.order(:name).pluck(:name).map { |club| club.strip }.uniq
    end
  end
end
