class ApplicationController < Kendocup::ApplicationController

  before_filter :set_locale
  before_filter :store_location_if_html, :only => [:index, :show]

  helper :all

  rescue_from CanCan::AccessDenied do |exception|
    # Rails.logger.debug "Access denied on #{exception.action} #{exception.subject.inspect}"
    if current_user.present?
      redirect_to root_path, alert: exception.message, status: 401
    else
      redirect_to new_user_session_path(locale: I18n.locale), alert: I18n.t("devise.failure.unauthenticated")
      # redirect_to new_user_session_path, alert: I18n.t("devise.failure.unauthenticated")
    end
  end

  def authenticate_admin_user!
    redirect_to root_url unless current_user.try(:admin?)
  end

  def default_url_options
    # Rails.logger.debug "mytext: default_url_options called"
    # default_url_options = {}
    # default_url_options[:locale] = I18n.locale if params[:locale].blank?
    # # default_url_options[:year] = Date.current.year if params[:year].blank?
    # return default_url_options
    { locale: I18n.locale }
  end

  def set_locale
    if flash
      notice = notice
      alert = alert
    end
    default_locale = 'en'
    begin
      request_language = request.env['HTTP_ACCEPT_LANGUAGE'].split('-')[0]
      request_language = (request_language.nil? || !['en', 'fr'].include?(request_language[/[^,;]+/])) ? nil : request_language[/[^,;]+/]
      params_locale = params[:locale] if params[:locale] == 'en' or params[:locale] == 'fr'

      @locale = params_locale || session[:locale] || request_language || default_locale
      I18n.locale = session[:locale] = @locale

      @inverse_locale = (@locale == 'en' ? 'fr' : 'en')

    rescue
      I18n.locale = session[:locale] = @locale = default_locale
      @inverse_locale = (@locale == 'en' ? 'fr' : 'en')
    end
  end


  def store_location_if_html
    store_location if ['text/html', 'application/javascript', 'text/javascript'].include?(request.format) && !['application/json'].include?(request.format)
  end

  def store_location
    session[:return_to] = request.fullpath
  end
  
  def back
    redirect_back_or_default
  end

  def redirect_back_or_default(default=root_path, options={})
    redirect_to(session[:return_to] || default, options)
    session[:return_to] = nil
  end

private

  def configure_permitted_parameters
    unless current_user_admin?
      devise_parameter_sanitizer.for(:sign_up) << :admin
    end
  end

end
