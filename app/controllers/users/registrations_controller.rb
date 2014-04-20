class Users::RegistrationsController < Devise::RegistrationsController

  def new
    super
  end

  def create
    @user = User.new(params[:user])
    if @user.save
      sign_in @user
      redirect_to new_user_enrollment_path(@user, self: true, locale: session[:locale])
      # set_flash_message(:notice, :success) if is_navigational_format?
      notice = t("devise.confirmations.send_instructions")
      # redirect_to root_path(locale: I18n.locale)
      # Rails.logger.info "alert #{flash}"
    else
      render action: :new
    end
  end

  def update
    super
  end
end
