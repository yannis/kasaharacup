class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception


  before_filter :configure_permitted_parameters, if: :devise_controller?
  before_filter :set_locale, :set_cup

  rescue_from CanCan::AccessDenied do |exception|
    # Rails.logger.debug "Access denied on #{exception.action} #{exception.subject.inspect}"
    if current_user.present?
      redirect_to root_path, alert: exception.message, status: 401
    else
      redirect_to new_user_session_path, alert: I18n.t("devise.failure.unauthenticated")
    end
  end

  def default_url_options
    {
      locale: I18n.locale,
      year: Date.current.year
     }
  end

  def set_locale
    if flash
      notice = notice
      alert = alert
    end
    default_locale = 'fr'
    begin
      request_language = request.env['HTTP_ACCEPT_LANGUAGE'].split('-')[0]
      request_language = (request_language.nil? || !['en', 'fr'].include?(request_language[/[^,;]+/])) ? nil : request_language[/[^,;]+/]
      params_locale = params[:locale] if params[:locale] == 'en' or params[:locale] == 'fr'

      @locale = params_locale || session[:locale] || request_language || default_locale
      I18n.locale = session[:locale] = @locale

      @inverse_locale = (@locale == 'en' ? 'fr' : 'en')

    rescue
      I18n.locale = session[:locale] = default_locale
    end
  end

  def set_cup
    @cup = Cup.where("EXTRACT(YEAR FROM start_on) = ?", params[:year]).first
  end

  # restrict access to admin module for non-admin users
  def authenticate_admin_user!
    redirect_to root_url unless current_user.try(:admin?)
  end


  def back
    redirect_back_or_default('/')
  end

  def redirect_back_or_default(default, options={})
    options.merge(:locale => I18n.locale) if options[:locale].blank?
    redirect_to(session[:return_to] || default, options)
    session[:return_to] = nil
  end

  protected

    def configure_permitted_parameters
      unless current_user_admin?
        devise_parameter_sanitizer.for(:sign_up) << :admin
      end
    end

    def current_user_admin?
      user_signed_in? && current_user.admin?
    end
end
