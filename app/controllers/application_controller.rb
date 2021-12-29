# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :set_locale, :set_current_cup

  def default_url_options
    {locale: I18n.locale}
  end

  private def set_locale
    params_locale = params[:locale] if params[:locale]&.to_sym&.in?(I18n.available_locales)
    session_locale = session[:locale] if session[:locale]&.to_sym&.in?(I18n.available_locales)
    request_locale = request
      .env["HTTP_ACCEPT_LANGUAGE"]
      &.scan(/^[a-z]{2}/)
      &.select { |locale| locale.to_sym.in?(I18n.available_locales) }

    @locale = params_locale.presence || session_locale.presence || request_locale.presence || I18n.default_locale
    I18n.locale = session[:locale] = @locale.to_sym
    @inverse_locale = (@locale.to_sym == :en ? :fr : :en)
  end

  private def set_current_cup
    return if @current_cup.present?

    future_cups = Cup.future.order("cups.start_on ASC")
    past_cups = Cup.past.order("cups.start_on DESC")
    if future_cups.present?
      @current_cup = future_cups.first
    elsif past_cups.present?
      @current_cup = past_cups.first
    else
      raise "Cup is missing!!!"
    end
  end

  private def configure_permitted_parameters
    unless current_user_admin?
      devise_parameter_sanitizer.for(:sign_up) << :admin
    end
  end

  private def check_deadline
    set_current_cup
    if !current_user.try("admin?") && Time.current > @current_cup.deadline
      flash[:alert] = t("kenshis.deadline_passed", email: "info@kendo-geneve.ch")
      redirect_to root_path and return
    end
  end
end
