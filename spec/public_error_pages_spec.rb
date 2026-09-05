# frozen_string_literal: true

require "rails_helper"

# What the error pages must *contain*. That they are actually served is a
# different question, asserted end to end in spec/requests/error_pages_spec.rb.
#
# Every error page is a static file in public/, served by
# ActionDispatch::PublicExceptions. Nothing in app/ renders them, so these
# assertions are the only thing standing between a hand edit and a broken
# error page.
RSpec.describe "Static error pages" do # rubocop:disable RSpec/DescribeClass
  # The statuses the app answers with a branded page. Anything else falls
  # through to PublicExceptions' X-Cascade: pass, which is an empty body with
  # the right status — acceptable, but not for these.
  let(:app_pages) { %w[400 404 406 422 500] }
  let(:heroku_pages) { %w[error maintenance] }

  let(:all_pages) do
    app_pages.to_h { |s| ["#{s}.html", app_page(s)] }
      .merge(heroku_pages.to_h { |n| ["heroku/#{n}.html", heroku_page(n)] })
  end

  def app_page(status) = Rails.public_path.join("#{status}.html").read

  def heroku_page(name) = Rails.public_path.join("heroku/#{name}.html").read

  # Names the pages that disagree with the rest, rather than every page that
  # was compared — otherwise a one-file drift reports all seven filenames and
  # the drift has to be found by hand.
  def odd_ones_out(by_name)
    by_name.group_by { |_, value| value }.values.min_by(&:size).map(&:first)
  end

  # An external stylesheet, image or font would not load: the asset host may be
  # the thing that is down, and the Heroku pages are served from a bucket. A
  # data: URI or an in-document fragment does not leave the page, so neither
  # counts.
  def external_references(html)
    dom = Nokogiri::HTML(html)

    (element_references(dom) + style_references(dom))
      .reject { |url| url.start_with?("data:", "#") }
  end

  # Every attribute that can pull a subresource, on any element, so this does
  # not have to be kept in sync with a list of tag names — a hand edit adding
  # <img srcset> or <link imagesrcset> is caught without touching the spec.
  # <a>/<area> hrefs are navigation rather than a subresource, and have their
  # own assertions below.
  def url_attributes = %w[href src srcset imagesrcset poster data xlink:href]

  def navigational_elements = %w[a area]

  def element_references(dom)
    dom.css("*")
      .reject { |node| navigational_elements.include?(node.name) }
      .flat_map { |node| url_attributes.filter_map { |attr| node[attr] } }
  end

  # The CSS lives in an inline <style>, and could just as easily arrive in a
  # style attribute; both are where an @import or a url() would most plausibly
  # appear and both are invisible to an attribute walk.
  def style_references(dom)
    css = dom.css("style").map(&:text) + dom.css("*").filter_map { |node| node["style"] }

    css.flat_map do |text|
      text.scan(/url\(\s*['"]?([^)'"]+)/).flatten + text.scan(/@import\s+['"]?([^;'"]+)/).flatten
    end
  end

  describe "every page" do
    it "is self-contained" do
      all_pages.each do |name, html|
        expect(external_references(html)).to be_empty, "#{name} references an external asset"
      end
    end

    # There is no locale negotiation on the error path: the session is gone and
    # Accept-Language is unreliable, so each page shows both languages rather
    # than guessing at one.
    it "shows both languages" do
      all_pages.each do |name, html|
        sections = Nokogiri::HTML(html).css("section[lang]").map { |s| s["lang"] }
        expect(sections).to contain_exactly("fr", "en"), "#{name} is not bilingual"
      end
    end

    # The one piece of chrome the bilingual body cannot cover: a French-only
    # title is what an English visitor sees in the tab, the bookmark and any
    # share preview.
    it "has a bilingual title" do
      all_pages.each do |name, html|
        title = Nokogiri::HTML(html).at_css("title").text

        expect(title).to include("/"), "#{name}'s title is not bilingual: #{title.inspect}"
      end
    end

    it "tells crawlers not to index it" do
      all_pages.each do |name, html|
        robots = Nokogiri::HTML(html).at_css('meta[name="robots"]')
        directives = robots&.[]("content").to_s.split(",").map { |d| d.strip.downcase }

        expect(directives).to include("noindex").or(include("none")),
          "#{name} is missing meta robots=noindex"
      end
    end

    # The pages are hand-written rather than generated, so nothing but this
    # stops the seven copies from drifting apart. Everything outside <title>
    # and <main> is shared boilerplate — the doctype, lang, both metas, the
    # stylesheet, the header and the footer — and all of it is compared, not
    # just the stylesheet.
    it "shares one identical page chrome" do
      chrome = all_pages.transform_values do |html|
        html.gsub(%r{<title>.*?</title>}m, "<title/>").gsub(%r{<main>.*?</main>}m, "<main/>")
      end

      expect(chrome.values.uniq.size).to eq(1),
        "these pages have drifted from the others: #{odd_ones_out(chrome).join(", ")}"
    end
  end

  describe "the app's own pages" do
    it "link back into the site in both languages" do
      app_pages.each do |status|
        hrefs = Nokogiri::HTML(app_page(status)).css("a").map { |a| a["href"] }

        expect(hrefs).to include("/fr").and(include("/en")), "#{status}.html has no way home"
      end
    end
  end

  describe "the Heroku pages" do
    # Not ENV["APP_HOST"], which is localhost here: these are served off-dyno
    # from a bucket, so a relative or localhost link is useless and the
    # production host is the only one that works.
    #
    # This pins the literal rather than deriving it, so it cannot notice on its
    # own that the site has moved. What it does catch is the half-done edit —
    # one page updated to a new host, the other stranded on the old one — and
    # it makes changing the host a deliberate, visible act rather than a quiet
    # one.
    let(:canonical_host) { "https://www.kasaharacup.com" }

    # Heroku renders these in an iframe from the bucket's origin: a relative
    # href resolves against the bucket, and a same-origin click is blocked.
    it "link out absolutely, in a new tab" do
      heroku_pages.each do |name|
        links = Nokogiri::HTML(heroku_page(name)).css("a")

        expect(links).not_to be_empty, "#{name}.html has no links out"
        links.each do |link|
          expect(link["href"]).to start_with(canonical_host),
            "#{name}.html links somewhere other than #{canonical_host}"
          expect(link["target"]).to eq("_blank"), "#{name}.html has a link without target=_blank"
          expect(link["rel"].to_s.split).to include("noopener"),
            "#{name}.html has a target=_blank link without rel=noopener"
        end
      end
    end
  end
end
