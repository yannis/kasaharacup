class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def facebook
    # You need to implement the method below in your model (e.g. app/models/user.rb)
    @user = User.find_for_facebook_oauth(request.env["omniauth.auth"], current_user)

    if @user.persisted?
      sign_in @user, event: :authentication #this will throw if @user is not activated
      # redirect_to user_path(@user, locale: I18n.locale)
      redirect_to root_path
      # redirect_to new_user_enrollment_path(@user, self: true, locale: session[:locale])
      set_flash_message(:notice, :success, kind: "Facebook") if is_navigational_format?
    else
      set_flash_message(:notice, :failure, kind: "Facebook", reason: @user.errors.full_messages.first) if is_navigational_format?
      session["devise.facebook_data"] = request.env["omniauth.auth"]
      redirect_to new_user_registration_path(locale: I18n.locale)
    end
  end
end
