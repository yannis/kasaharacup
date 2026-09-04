# frozen_string_literal: true

require "rails_helper"

RSpec.describe "StaticPages" do
  let!(:cup) { create(:cup, start_on: Date.new(2026, 9, 26), end_on: Date.new(2026, 9, 27)) }

  describe "GET /about" do
    it "returns http success" do
      get about_path
      expect(response).to have_http_status(:success)
    end

    it "renders the three paragraphs as siblings of one prose block, none sized apart" do
      get about_path(locale: :fr)
      paragraphs = response.parsed_body.css("div.prose > p")
      expect(paragraphs.size).to be 3
      expect(paragraphs.map { |paragraph| paragraph.attr("class") }).to all(be_nil)
    end

    context "in French" do
      it "announces the upcoming edition and its dates" do
        get about_path(locale: :fr)
        expect(response.body).to include(
          "La #{cup.edition}ème édition de la Coupe Kasahara aura lieu les 26 et 27 septembre 2026"
        )
      end
    end

    context "in English" do
      it "announces the upcoming edition and its dates" do
        get about_path(locale: :en)
        expect(response.body).to include(
          "The #{cup.edition.ordinalize} edition of the Kasahara Cup will take place on 26 and 27 September, 2026"
        )
      end
    end

    context "when the latest cup is in the past" do
      let!(:cup) { create(:cup, start_on: Date.new(2020, 9, 26), end_on: Date.new(2020, 9, 27)) }

      it "speaks of it in the past tense" do
        get about_path(locale: :fr)
        expect(response.body).to include("a eu lieu les 26 et 27 septembre 2020")
        expect(response.body).not_to include("édition de la Coupe Kasahara aura lieu")
      end
    end

    context "with a single-day cup" do
      let!(:cup) { create(:cup, start_on: Date.new(2026, 9, 26), end_on: nil) }

      it "names the one day" do
        get about_path(locale: :fr)
        expect(response.body).to include("aura lieu le 26 septembre 2026")
      end
    end

    context "when the current cup is canceled" do
      let!(:cup) {
        create(:cup, start_on: Date.new(2026, 9, 26), end_on: Date.new(2026, 9, 27), canceled_at: Time.current)
      }

      it "omits the edition sentence rather than inventing a number" do
        get about_path(locale: :fr)
        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("édition de la Coupe Kasahara")
      end
    end
  end
end
