# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include HasLocale
  include HasHttpAuth
  include ActiveStorage::SetCurrent

  before_action :set_current_cup
  if Rails.env.development?
    around_action :n_plus_one_detection

    private def n_plus_one_detection
      Prosopite.scan
      yield
    ensure
      Prosopite.finish
    end
  end

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

  # Every PDF leaves through here, so none of them can go out missing what a
  # browser reads to know what it has been handed: the content type, and a
  # filename ending in .pdf. Sent bare, a poster arrives as a nameless blob the
  # operating system will not open on a double-click.
  #
  # The name is parameterized here rather than at each call site — a category
  # called "souriant(e) Chronos" otherwise reached the browser percent-encoded.
  private def send_pdf(pdf, filename:)
    send_data pdf.render,
      filename: "#{filename.parameterize(separator: "_")}.pdf",
      type: "application/pdf",
      disposition: "inline"
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
