# frozen_string_literal: true

require "rails_helper"

# The end-to-end path: a real exception, dispatched through
# config.exceptions_app, reaching the pages built in the previous tasks.
RSpec.describe "Error handling", type: :request do
  # Two env keys have to be overridden, not one. railties' Rails::Application
  # (lib/rails/application.rb:325) derives show_detailed_exceptions from
  # consider_all_requests_local, which config/environments/test.rb sets to
  # true. Left alone, DebugExceptions (middleware 19) renders Rails' diagnostic
  # page and ShowExceptions (17) never reaches the exceptions app.
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

  let!(:cup) { create(:cup) }

  it "renders the 404 page for an unknown URL" do
    get "/fr/no-such-page"

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.css("h1").text).to eq I18n.t("error_pages.statuses.404.title", locale: :fr)
  end

  it "keeps the locale of the failed request" do
    get "/en/no-such-page"

    expect(response.parsed_body.css("html").attr("lang").value).to eq "en"
  end

  it "renders the 404 page for a RecordNotFound raised inside a controller" do
    allow(Cup).to receive(:future).and_raise(ActiveRecord::RecordNotFound)

    get root_path(locale: :fr)

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.css("h1").text).to eq I18n.t("error_pages.statuses.404.title", locale: :fr)
  end

  # The whole point of routing /500 to PublicExceptions: no controller, no
  # view, no database on the path that renders a broken app.
  it "serves the static 500 page for an unhandled exception" do
    allow(Cup).to receive(:future).and_raise("boom")

    get root_path(locale: :fr)

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to eq Rails.public_path.join("500.html").read
  end
end
