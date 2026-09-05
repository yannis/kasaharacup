# frozen_string_literal: true

module ErrorPages
  # Picks the locale for an error page.
  #
  # `HasLocale` cannot be reused here: it writes `session[:locale]`, and under
  # `config.exceptions_app` the session is either missing entirely (for an
  # exception raised above `ActionDispatch::Session` in the stack) or silently
  # discarded, because `CookieStore` commits on the way back up and the
  # exception unwinds past it.
  class Locale
    def initialize(request)
      @request = request
    end

    def to_sym
      from_query || from_original_path || from_accept_language || I18n.default_locale
    end

    # A malformed query string is itself a 400; parsing it again here would
    # raise inside the error page and fall through to Rails' plain-text
    # failsafe response.
    private def from_query
      available(@request.GET["locale"])
    rescue
      nil
    end

    private def from_original_path
      available(@request.get_header("action_dispatch.original_path").to_s.split("/").second)
    end

    private def from_accept_language
      @request.get_header("HTTP_ACCEPT_LANGUAGE").to_s
        .scan(/[a-z]{2}/)
        .lazy
        .filter_map { |code| available(code) }
        .first
    end

    private def available(code)
      code.to_s.to_sym.presence_in(I18n.available_locales)
    end
  end
end
