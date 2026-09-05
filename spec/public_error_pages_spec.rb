# frozen_string_literal: true

require "rails_helper"

# Every error page is a static file in public/, served by
# ActionDispatch::PublicExceptions. Nothing in app/ renders them, so these
# assertions are the only thing standing between a hand edit and a broken
# error page.
RSpec.describe "Static error pages" do # rubocop:disable RSpec/DescribeClass
  # The statuses the app can actually answer. Anything else falls through to
  # PublicExceptions' X-Cascade: pass, which is an empty body with the right
  # status — acceptable, but not for these.
  let(:app_pages) { %w[400 404 406 422 500] }
  let(:heroku_pages) { %w[error maintenance] }

  def app_page(status) = Rails.public_path.join("#{status}.html").read

  def heroku_page(name) = Rails.public_path.join("heroku/#{name}.html").read

  def all_pages
    app_pages.to_h { |s| ["#{s}.html", app_page(s)] }
      .merge(heroku_pages.to_h { |n| ["heroku/#{n}.html", heroku_page(n)] })
  end

  # An external stylesheet, image or font would not load: the asset host may be
  # the thing that is down, and the Heroku pages are served from a bucket.
  # Both the DOM and the raw text are checked — the CSS lives in an inline
  # <style>, which is where an @import or a url() would most plausibly appear
  # and which a DOM walk alone would miss.
  def external_references(html)
    dom = Nokogiri::HTML(html)
    nodes = dom.css("link[href], script[src], img[src], source[src], source[srcset], " \
                    "iframe[src], video[poster], object[data], use[href], embed[src]")
    attrs = nodes.map { |n| n["href"] || n["src"] || n["srcset"] || n["poster"] || n["data"] }
    css_urls = dom.css("style").flat_map { |s| s.text.scan(/url\(\s*['"]?([^)'"]+)/).flatten }
    css_imports = dom.css("style").flat_map { |s| s.text.scan(/@import\s+['"]?([^;'"]+)/).flatten }
    attrs + css_urls + css_imports
  end

  it "covers every status the app answers" do
    app_pages.each do |status|
      expect(Rails.public_path.join("#{status}.html")).to exist
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

    it "tells the visitor not to index it" do
      all_pages.each do |name, html|
        robots = Nokogiri::HTML(html).at_css('meta[name="robots"]')
        expect(robots&.[]("content")).to eq("noindex"), "#{name} is missing meta robots=noindex"
      end
    end

    # The pages are hand-written rather than generated, so nothing but this
    # stops the seven copies of the stylesheet from drifting apart.
    it "shares one identical stylesheet" do
      styles = all_pages.transform_values { |html| Nokogiri::HTML(html).css("style").map(&:text) }

      expect(styles.values.uniq.size).to eq(1),
        "these pages have diverging <style> blocks: #{styles.keys.join(", ")}"
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
    # from a bucket, so the production host is the only one that works. Pinned
    # rather than matched loosely so a domain change fails here instead of
    # silently stranding the platform error page on the old name.
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
        end
      end
    end
  end
end
