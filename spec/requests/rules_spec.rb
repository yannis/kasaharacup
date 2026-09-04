# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rules", :en do
  let!(:cup) { create(:cup, start_on: Date.new(2026, 9, 26), end_on: Date.new(2026, 9, 27)) }

  # The section ids are set explicitly in the locale text because kramdown
  # derives them from the heading text: left implicit, the duplicated "Pool" and
  # "Tournament" headings collide (#pool, #pool-1) and the French page emits
  # #poule instead, breaking a shared link the moment a reader switches locale.
  let(:section_ids) {
    %w[team team-pool team-tournament individual individual-pool individual-tournament]
  }

  describe "GET /en/rules" do
    it "returns http success" do
      get rules_path(locale: :en)
      expect(response).to have_http_status(:success)
    end

    it "renders the markdown as a single h1 → h2 → h3 hierarchy" do
      get rules_path(locale: :en)
      body = response.parsed_body
      expect(body.css("div.prose h1").map(&:text)).to eq ["Competition rules"]
      expect(body.css("div.prose h2").map(&:text)).to eq ["Team competition", "Individual competition"]
      expect(body.css("div.prose h3").map(&:text)).to eq %w[Pool Tournament Pool Tournament]
      expect(body.css("div.prose h4, div.prose h5")).to be_empty
    end

    it "gives every section a stable explicit id" do
      get rules_path(locale: :en)
      headings = response.parsed_body.css("div.prose h2, div.prose h3")
      expect(headings.map { |heading| heading.attr("id") }).to eq section_ids
    end

    it "points the contents list at those ids" do
      get rules_path(locale: :en)
      hrefs = response.parsed_body.css("div.prose ul li a").map { |link| link.attr("href") }
      expect(hrefs).to eq %w[#team-pool #team-tournament #individual-pool #individual-tournament]
    end

    it "links the EKF rules document it is based on" do
      get rules_path(locale: :en)
      expect(response.parsed_body.css("div.prose a").map { |link| link.attr("href") })
        .to include("https://www.ekf-eu.com/documents/34EKC%202026%20RULES_FINAL.pdf")
    end

    it "renders the tie-break criteria as ordered lists, not literal markdown" do
      get rules_path(locale: :en)
      lists = response.parsed_body.css("div.prose ol")
      expect(lists.map { |list| list.css("li").size }).to eq [4, 8, 5]
      expect(response.body).not_to include("1. Highest number")
    end

    it "carries content from all four sections" do
      get rules_path(locale: :en)
      expect(response.body).to include("the duration is 4 minutes for all categories")
      expect(response.body).to include("4 minutes for juniors and 5 minutes for seniors")
      expect(response.body).to include("The combat time is 4 minutes")
      expect(response.body).to include("5 minutes for seniors and 4 minutes for juniors")
    end
  end

  describe "GET /fr/rules", :fr do
    it "returns http success" do
      get rules_path(locale: :fr)
      expect(response).to have_http_status(:success)
    end

    it "renders the French headings" do
      get rules_path(locale: :fr)
      body = response.parsed_body
      expect(body.css("div.prose h1").map(&:text)).to eq ["Règlement de la compétition"]
      expect(body.css("div.prose h2").map(&:text)).to eq ["Compétition par équipe", "Compétition individuelle"]
      expect(body.css("div.prose h3").map(&:text)).to eq %w[Poule Tournoi Poule Tournoi]
    end

    it "keeps the section ids identical to the English page, so a shared link survives a locale switch" do
      get rules_path(locale: :fr)
      headings = response.parsed_body.css("div.prose h2, div.prose h3")
      expect(headings.map { |heading| heading.attr("id") }).to eq section_ids
    end

    it "carries content from all four sections" do
      get rules_path(locale: :fr)
      expect(response.body).to include("durent 4 minutes dans toutes les catégories")
      expect(response.body).to include("4 minutes pour les juniors et de 5 minutes pour les seniors")
      expect(response.body).to include("Le temps de combat est de 4 minutes")
      expect(response.body).to include("5 minutes pour les seniors et de 4 minutes pour les juniors")
    end

    it "leaves the Japanese kendo terms untranslated" do
      get rules_path(locale: :fr)
      expect(response.body).to include(
        "sanbon-shobu", "ippon-shobu", "hikiwake", "kettei-sen", "encho", "hantei", "chusen"
      )
    end
  end

  describe "the navigation link" do
    # On this page the locale dropdown also points at /en/rules and /fr/rules —
    # it switches the locale of the current URL — so the menu links are picked
    # out by their label rather than by href alone.
    def menu_links(label)
      response.parsed_body.css("nav a").select { |link| link.text.strip == label }
    end

    it "appears in both the desktop row and the mobile menu" do
      get rules_path(locale: :en)
      links = menu_links("Rules")
      expect(links.size).to eq 2
      expect(links.map { |link| link.attr("href") }).to all(eq "/en/rules")
    end

    it "preserves the locale it is rendered in", :fr do
      get rules_path(locale: :fr)
      links = menu_links("Règlement")
      expect(links.size).to eq 2
      expect(links.map { |link| link.attr("href") }).to all(eq "/fr/rules")
    end
  end

  describe "page metadata" do
    it "gives the rules page its own browser and share title" do
      get rules_path(locale: :en)
      expected = "Competition rules — Kasahara Cup #{cup.year}"
      expect(response.parsed_body.css("title").text.strip).to eq expected
      expect(response.parsed_body.css("meta[property='og:title']").attr("content").value).to eq expected
    end

    it "leaves a page that declares no title of its own on the cup-only fallback" do
      get cup_path(cup, locale: :en)
      expect(response.parsed_body.css("title").text.strip).to eq "Kasahara Cup #{cup.year}"
    end
  end
end
