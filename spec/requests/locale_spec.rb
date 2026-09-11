# frozen_string_literal: true

require "rails_helper"

# Every public route lives under `scope ":locale"`, so `params[:locale]` is
# always set there and settles the question before the header is reached. The
# admin routes are not scoped, which is where `Accept-Language` actually
# decides. The paths below are written out rather than built from the helpers
# because `HasLocale#default_url_options` appends `?locale=` to a path that has
# no locale segment, which is exactly the parameter these examples must not send.
RSpec.describe "Locale negotiation" do
  let!(:cup) { create(:cup) }
  let(:admin) { create(:user, :admin) }
  let(:team_category) { create(:team_category, cup: cup) }
  let(:unscoped_path) { "/admin/team_categories/#{team_category.id}/encounters" }

  # `set_locale` assigns `I18n.locale` in a before_action and nothing in
  # spec/support resets it globally, so these examples would otherwise leave the
  # process on `:en` for whichever example RSpec runs next.
  around { |example| I18n.with_locale(I18n.default_locale) { example.run } }

  before { sign_in admin }

  def resolved_locale(accept_language = nil)
    headers = accept_language ? {"Accept-Language" => accept_language} : {}
    get unscoped_path, headers: headers
    expect(response).to have_http_status(:success)
    session[:locale].to_sym
  end

  it "falls back to the default locale when the request sends no header" do
    expect(resolved_locale).to eq :fr
  end

  it "serves English to a visitor whose browser offers it second" do
    expect(resolved_locale("de-DE,en;q=0.9")).to eq :en
  end

  it "serves English to a client sending uppercase language tags" do
    expect(resolved_locale("EN-US,EN;q=0.9")).to eq :en
  end

  it "follows q-values rather than the order the tags appear in" do
    expect(resolved_locale("de-DE,fr;q=0.1,en;q=0.9")).to eq :en
  end

  it "prefers the locale in the path over the header" do
    get "/en/about", headers: {"Accept-Language" => "fr"}
    expect(session[:locale].to_sym).to eq :en
  end

  it "prefers a locale already established in the session over the header" do
    get "/en/about"

    get unscoped_path, headers: {"Accept-Language" => "fr"}
    expect(session[:locale].to_sym).to eq :en
  end
end
