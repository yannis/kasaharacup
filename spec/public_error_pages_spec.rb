# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Static error pages" do # rubocop:disable RSpec/DescribeClass
  let(:static_500) { Rails.public_path.join("500.html").read }
  let(:heroku_pages) do
    {
      "error" => Rails.public_path.join("heroku/error.html").read,
      "maintenance" => Rails.public_path.join("heroku/maintenance.html").read
    }
  end

  # An external stylesheet, image or font would not load: the asset host may be
  # the thing that is down, and the Heroku pages are served from a bucket.
  def external_references(html)
    Nokogiri::HTML(html).css("link[href], script[src], img[src]").map { |node| node["href"] || node["src"] }
  end

  it "keeps public/500.html self-contained and bilingual" do
    expect(external_references(static_500)).to be_empty
    expect(static_500).to include('lang="fr"').and include('lang="en"')
  end

  describe "the Heroku pages" do
    it "are self-contained and bilingual" do
      heroku_pages.each do |name, html|
        expect(external_references(html)).to be_empty, "#{name}.html references an external asset"
        expect(html).to include('lang="fr"').and(include('lang="en"')), "#{name}.html is not bilingual"
      end
    end

    # Heroku renders these in an iframe from the bucket's origin: a relative
    # href resolves against the bucket, and a same-origin click is blocked.
    it "link out absolutely, in a new tab" do
      heroku_pages.each do |name, html|
        links = Nokogiri::HTML(html).css("a")

        expect(links).not_to be_empty, "#{name}.html has no links out"
        links.each do |link|
          expect(link["href"]).to start_with("https://"), "#{name}.html has a relative link"
          expect(link["target"]).to eq("_blank"), "#{name}.html has a link without target=_blank"
        end
      end
    end
  end
end
