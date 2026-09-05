# frozen_string_literal: true

require "rails_helper"

# These hit the error routes directly. The end-to-end path — a real exception
# dispatched through `config.exceptions_app` — is covered in
# spec/requests/error_handling_spec.rb.
RSpec.describe "Errors", type: :request do
  it "renders the 404 page with a 404 status" do
    get "/404"

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.css("h1").text).to eq I18n.t("error_pages.statuses.404.title", locale: :fr)
  end

  it "renders in French by default" do
    get "/404"

    expect(response.parsed_body.css("html").attr("lang").value).to eq "fr"
  end

  it "honours Accept-Language" do
    get "/404", headers: {"HTTP_ACCEPT_LANGUAGE" => "en-GB,en;q=0.9"}

    expect(response.parsed_body.css("html").attr("lang").value).to eq "en"
    expect(response.parsed_body.css("h1").text).to eq I18n.t("error_pages.statuses.404.title", locale: :en)
  end

  it "honours an explicit ?locale=, so the page can be previewed" do
    get "/404?locale=en"

    expect(response.parsed_body.css("html").attr("lang").value).to eq "en"
  end

  it "offers recovery links that need no database" do
    get "/404"

    hrefs = response.parsed_body.css("main a").map { |link| link.attr("href") }
    expect(hrefs).to include("/fr", "/fr/rules")
  end

  it "renders 403 and 422 too" do
    get "/403"
    expect(response).to have_http_status(:forbidden)

    get "/422"
    expect(response).to have_http_status(422)
  end

  # ActionDispatch::ExceptionWrapper maps StaleObjectError to 409 and
  # NotImplemented to 501; neither has its own copy.
  it "falls back to generic copy for a status with no dedicated message" do
    get "/409"

    expect(response).to have_http_status(409)
    expect(response.parsed_body.css("h1").text).to eq I18n.t("error_pages.statuses.default.title", locale: :fr)
  end

  # Without `formats: [:html]` this returns an empty body, because there is no
  # show.pdf template and the router answers X-Cascade: pass.
  it "returns an HTML body even when the request asks for another format" do
    get "/404.pdf"

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("<h1>")
  end

  describe "GET /500" do
    # ActionDispatch::Static serves public/500.html ahead of the router, so
    # this returns 200. The 500 status only appears on the exceptions_app
    # path, which bypasses middleware — see error_handling_spec.rb.
    #
    # The absent stylesheet link is what proves no controller rendered this:
    # the ErrorsController layout emits one, and the static page has none.
    it "serves the new self-contained page, not the controller's" do
      get "/500"

      expect(response.body).to include('lang="fr"').and include('lang="en"')
      expect(response.body).not_to include("stylesheet")
    end
  end
end
