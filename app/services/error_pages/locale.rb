# frozen_string_literal: true

module ErrorPages
  # Picks the locale for an error page.
  #
  # `HasLocale` cannot be reused here: it writes `session[:locale]`, and under
  # `config.exceptions_app` the session is either missing entirely (for an
  # exception raised above `ActionDispatch::Session` in the stack) or silently
  # discarded, because `CookieStore` commits on the way back up and the
  # exception unwinds past it.
  #
  # An explicit `?locale=` wins over the failed request's path, so the pages can
  # be previewed in either language at `/404?locale=en`. That inverts
  # `HasLocale`, where a path segment beats a query parameter.
  #
  # `Accept-Language` handling diverges from `HasLocale` too: its anchored
  # `scan(/^[a-z]{2}/)` reads only the first tag and so cannot skip a language
  # the site does not offer. Aligning the two is worth doing, but not from the
  # error path.
  class Locale
    def initialize(request)
      @request = request
    end

    def resolve
      from_query || from_original_path || from_accept_language || I18n.default_locale
    end

    # `Request#GET` re-raises a malformed query string as
    # ActionController::BadRequest — itself one of the errors this page has to
    # render. Parsing it again here would raise inside the error page and fall
    # through to Rails' plain-text failsafe response.
    private def from_query
      available(@request.GET["locale"])
    rescue
      nil
    end

    private def from_original_path
      available(@request.get_header("action_dispatch.original_path").to_s.split("/").second)
    end

    # Language tags are case-insensitive, and header order is not preference
    # order — q-values are. `sort_by` is not stable in Ruby, so the index breaks
    # ties and keeps "en,fr" reading left to right.
    private def from_accept_language
      @request.get_header("HTTP_ACCEPT_LANGUAGE").to_s.downcase
        .split(",")
        .each_with_index
        .sort_by { |tag, index| [-(tag[/q=([\d.]+)/, 1]&.to_f || 1.0), index] }
        .lazy
        .filter_map { |tag, _index| available(tag[/\b[a-z]{2}\b/]) }
        .first
    end

    private def available(code)
      code.to_s.to_sym.presence_in(I18n.available_locales)
    end
  end
end
