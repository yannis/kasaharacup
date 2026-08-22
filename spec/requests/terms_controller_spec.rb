# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TermsController" do
  around do |example|
    original_contact_email = ENV["CONTACT_EMAIL"]
    ENV["CONTACT_EMAIL"] = "contact@example.org"
    example.run
    ENV["CONTACT_EMAIL"] = original_contact_email
  end

  let!(:cup) { create(:cup) }

  describe "GET /:locale/cups/:year/terms" do
    it "renders every English clause and the contact mailto link" do
      get cup_terms_path(cup, locale: :en)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("refunded in full, less any bank transfer charges")
      expect(response.body).to include("no refund will be made")
      expect(response.body).to include(
        "Should the event be cancelled by the organizers, registration fees already paid will be refunded in full."
      )
      expect(response.body).to include('href="mailto:contact@example.org"')
    end

    it "renders the French clauses" do
      get cup_terms_path(cup, locale: :fr)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("intégralement remboursés, déduction faite des éventuels frais bancaires")
      expect(response.body).to include("aucun remboursement ne sera effectué")
    end

    it "renders the registration deadline in the banner's datetime format" do
      # The factory sets deadline to start_on - 14.days, distinct from both the
      # model default (-7.days) and the payment deadline (-4.days), so this
      # proves the page reads Cup#deadline.
      get cup_terms_path(cup, locale: :en)

      expect(response.body).to include(I18n.l(cup.deadline, format: :long, locale: :en))
    end

    it "renders the requested cup's page shell for a historical cup" do
      historical_cup = create(:cup, start_on: "2019-08-01")

      get cup_terms_path(historical_cup, locale: :en)

      expect(response).to have_http_status(:success)
      expect(response.body).to match(%r{<title>\s*Kasahara Cup 2019\s*</title>})
    end

    it "returns 404 for an unknown cup year" do
      get "/en/cups/1900/terms"

      expect(response).to have_http_status(:not_found)
    end
  end
end
