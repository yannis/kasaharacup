# frozen_string_literal: true

module HasHttpAuth
  extend ActiveSupport::Concern

  included do
    before_action :http_auth
  end

  private def http_auth
    return if [ENV["HTTP_AUTH_USERNAME"], ENV["HTTP_AUTH_PASSWORD"]].all?(&:blank?)

    authenticate_or_request_with_http_basic do |username, password|
      username == ENV["HTTP_AUTH_USERNAME"] && password == ENV["HTTP_AUTH_PASSWORD"]
    end
  end
end
