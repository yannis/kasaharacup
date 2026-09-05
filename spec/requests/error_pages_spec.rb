# frozen_string_literal: true

require "rails_helper"

# The files in public/ are only worth anything if Rails actually serves them,
# and nothing in app/ says that it does: ActionDispatch::ShowExceptions maps the
# exception to a status and ActionDispatch::PublicExceptions reads the matching
# file. That wiring is invisible — no route, no controller, no view — so an
# unrelated change (setting config.exceptions_app, adding a catch-all route)
# can take every branded page out of production without another spec noticing.
RSpec.describe "Error pages", type: :request do
  # Two env keys have to be overridden, not one. Rails::Application derives
  # show_detailed_exceptions from consider_all_requests_local, which
  # config/environments/test.rb sets to true. Left alone, DebugExceptions
  # renders Rails' diagnostic page — with the right status, but not this
  # markup — and ShowExceptions never reaches PublicExceptions. They are
  # restored afterwards, or every later spec in the run renders error pages
  # instead of raising.
  around do |example|
    env = Rails.application.env_config
    show = env["action_dispatch.show_exceptions"]
    detailed = env["action_dispatch.show_detailed_exceptions"]
    env["action_dispatch.show_exceptions"] = :all
    env["action_dispatch.show_detailed_exceptions"] = false
    example.run
  ensure
    env["action_dispatch.show_exceptions"] = show
    env["action_dispatch.show_detailed_exceptions"] = detailed
  end

  # Byte equality, not a heading match: PublicExceptions serves the file
  # verbatim, so anything less would pass on a half-served page.
  def page(status) = Rails.public_path.join("#{status}.html").read

  it "serves 404.html for an unrouted path" do
    get "/fr/no-such-page"

    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq page(404)
  end

  it "serves 406.html when no requested format can be served" do
    get "/fr", headers: {"HTTP_ACCEPT" => "!!!not-a-media-type"}

    expect(response).to have_http_status(:not_acceptable)
    expect(response.body).to eq page(406)
  end

  # set_current_cup is the first database call on the root path, which makes it
  # the cheapest place to raise from inside a controller.
  describe "an exception raised inside a controller" do
    it "serves 500.html when it is unhandled" do
      allow(Cup).to receive(:future).and_raise("boom")

      get "/fr"

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to eq page(500)
    end

    it "serves 422.html for a request Rails rejects" do
      allow(Cup).to receive(:future).and_raise(ActionController::InvalidAuthenticityToken)

      get "/fr"

      expect(response).to have_http_status(422)
      expect(response.body).to eq page(422)
    end
  end

  # These die in Rack's parameter parsing, so no controller runs at all.
  describe "unparseable parameters" do
    it "serves 400.html for a malformed query string" do
      get "/fr?locale=%"

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq page(400)
    end

    # A route that actually accepts POST, so the body is parsed rather than the
    # request dying at routing first.
    it "serves 400.html for a malformed form body" do
      cup = create(:cup)

      post "/fr/cups/#{cup.to_param}/kenshis",
        params: "a[]=1&a[b]=2",
        headers: {"CONTENT_TYPE" => "application/x-www-form-urlencoded"}

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to eq page(400)
    end
  end

  # What serving the pages statically buys, and what regressed while they were
  # rendered through a controller: PublicExceptions gives a HEAD request no
  # body and a JSON client JSON, rather than an HTML page either way.
  describe "clients that do not want the page" do
    it "sends no body for a HEAD request" do
      head "/fr/no-such-page"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to be_empty
    end

    it "answers a JSON client with JSON" do
      get "/fr/no-such-page", headers: {"HTTP_ACCEPT" => "application/json"}

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to include("status" => 404)
    end
  end
end
