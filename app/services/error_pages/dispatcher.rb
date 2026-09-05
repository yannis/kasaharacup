# frozen_string_literal: true

module ErrorPages
  # The exceptions app: hands the request to the router with unparseable
  # parameters stripped first.
  #
  # A malformed query string or form body is itself a 400, and
  # `ActionController::Instrumentation#process_action` reads
  # `request.filtered_parameters` while building its payload — before the
  # action runs. So `ErrorsController` cannot avoid re-parsing them however
  # carefully the action is written; using `request.path_parameters` instead of
  # `params` is not enough. That second parse raises inside the exceptions app,
  # and `ActionDispatch::ShowExceptions` answers a raising exceptions app with
  # its plain-text failsafe. The visitor sends one bad parameter and gets an
  # unstyled "500 Internal Server Error" where a branded 400 belongs.
  class Dispatcher
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(parseable?(env) ? env : without_parameters(env))
    end

    # Both parse into the env on success, so the controller does not repeat the
    # work. Neither touches path_parameters, which the router has yet to set.
    private def parseable?(env)
      request = ActionDispatch::Request.new(env)
      request.GET
      request.POST
      true
    rescue
      false
    end

    # The error page reads no parameters of its own beyond `?locale=`, which is
    # a preview convenience, so dropping them costs nothing and is the only way
    # to guarantee the page renders.
    #
    # Replacing `rack.input` is not enough on its own. Rack::MethodOverride
    # reads the body on the way down looking for `_method`, swallows the parse
    # error, and leaves the raw data cached in `rack.request.form_*`; Rack then
    # re-parses from that cache in preference to the input. Those keys, and
    # Rails' own memoised parameter hashes, have to go with it.
    PARAMETER_CACHE_KEYS = %w[
      action_dispatch.request.parameters
      action_dispatch.request.query_parameters
      action_dispatch.request.request_parameters
    ].freeze

    private def without_parameters(env)
      env
        .except(*PARAMETER_CACHE_KEYS, *env.keys.grep(/\Arack\.request\.form_/))
        .merge(
          "QUERY_STRING" => "",
          "CONTENT_LENGTH" => "0",
          "rack.input" => StringIO.new
        )
    end
  end
end
