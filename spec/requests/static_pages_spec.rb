# frozen_string_literal: true

require "rails_helper"

RSpec.describe "StaticPages" do
  let!(:cup) { create(:cup) }

  describe "GET /about" do
    it "returns http success" do
      get about_path
      expect(response).to have_http_status(:success)
    end

    it "links to the current cup's registration terms from the footer" do
      get about_path

      expect(response.body).to include(cup_terms_path(cup))
      expect(response.body).to include(CGI.escapeHTML(I18n.t("layouts.footer.terms")))
    end
  end
end
