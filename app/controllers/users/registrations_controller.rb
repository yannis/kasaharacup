# encoding: UTF-8

class Users::RegistrationsController < Devise::RegistrationsController

  def new
    super
  end

  def create
    @user = User.new(my_sanitizer)
    if @user.save
      sign_in @user
      redirect_to new_cup_user_kenshi_path(@current_cup, @user, self: true)
      # set_flash_message(:notice, :success) if is_navigational_format?
      notice = t("devise.confirmations.send_instructions")
      # redirect_to root_path(locale: I18n.locale)
      # Rails.logger.info "alert #{flash}"
    else
      render action: :new
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
      # Sign in the user bypassing validation in case his password changed
      sign_in @user, bypass: true
      redirect_to cup_user_path(@current_cup, @user)
      # redirect_to after_update_path_for(@user)
    else
      render "edit"
    end
  end

  protected

    def my_sanitizer
      if current_user.try("admin?")
        params.require(:user).permit(:first_name, :last_name, :email, :dob, :female, :club_id, :club_name, :admin, :password, :password_confirmation, :current_password)
      else
        params.require(:user).permit(:first_name, :last_name, :email, :dob, :female, :club_id, :club_name, :password, :password_confirmation, :current_password)
      end
    end

  private
    # check if we need password to update user data
    # ie if password or email was changed
    # extend this as needed
    def needs_password?(user, params)
      user.email != params[:user][:email] ||
        params[:user][:password].present?
    end
end
