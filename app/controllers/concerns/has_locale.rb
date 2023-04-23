# frozen_string_literal: true

module HasLocale
  extend ActiveSupport::Concern

  included do
    before_action :set_locale
  end

  private def set_locale
    params_locale = params[:locale] if params[:locale]&.to_sym&.in?(I18n.available_locales)
    session_locale = session[:locale] if session[:locale]&.to_sym&.in?(I18n.available_locales)
    request_locale = request
      .env["HTTP_ACCEPT_LANGUAGE"]
      &.scan(/^[a-z]{2}/)
      &.find { |locale| locale.to_sym.in?(I18n.available_locales) }

    @locale = params_locale.presence || session_locale.presence || request_locale.presence || I18n.default_locale
    I18n.locale = session[:locale] = @locale.to_sym
    @inverse_locale = ((@locale.to_sym == :en) ? :fr : :en)
  end

  def default_url_options
    {locale: I18n.locale}
  end
end
