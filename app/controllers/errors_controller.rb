# frozen_string_literal: true

# The branded 4xx pages, reached through `config.exceptions_app`.
#
# It inherits ActionController::Base rather than ApplicationController on
# purpose. Every filter on ApplicationController is a liability on the error
# path: `set_current_cup` queries Cup and raises "Cup is missing!!!" when there
# are none — and the failure being rendered may be the database itself;
# `HasLocale` writes a session that is never committed here; `HasHttpAuth`
# would demand basic auth on an error page. The application layout needs
# @current_cup, and _navigation needs current_user, so neither is used.
class ErrorsController < ActionController::Base # rubocop:disable Rails/ApplicationController
  layout "error"

  around_action :switch_locale

  def show
    # `request.path_parameters`, not `params`: `params` parses the query
    # string, and a malformed query string is itself one of the errors this
    # page has to render.
    @status = request.path_parameters[:id].to_i
    render :show, status: @status, formats: [:html]
  end

  # The i18n railtie has no per-request reset hook, so assigning I18n.locale
  # directly would leave the value on the Puma thread after the response.
  private def switch_locale(&action)
    I18n.with_locale(ErrorPages::Locale.new(request).to_sym, &action)
  end
end
