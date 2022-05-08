# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include HasLocale
  include HasHttpAuth
  include ActiveStorage::SetCurrent

  before_action :set_current_cup

  rescue_from CanCan::AccessDenied do |exception|
    if current_user.present?
      redirect_to root_path, alert: exception.message
    else
      redirect_to new_user_session_path(locale: I18n.locale), alert: I18n.t("devise.failure.unauthenticated")
    end
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
      flash[:alert] = t("kenshis.deadline_passed", email: ENV.fetch("CONTACT_EMAIL"))
      redirect_to root_path and return
    end
  end

  private def prevent_page_caching
    @cache_disabled = true
    h = response.headers
    h["Cache-Control"] = "no-cache, no-store, must-revalidate"
    h["Pragma"] = "no-cache"
    h["Expires"] = "0"
    h.delete("ETag")
  end
end
