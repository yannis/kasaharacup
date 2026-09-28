# frozen_string_literal: true

require "rails_helper"

RSpec.describe Results::IndividualCategoryComponent, type: :component do
  let(:individual_category) { create(:individual_category) }

  it "leaves out the attachments box when there is nothing to attach" do
    render_inline(described_class.new(individual_category: individual_category))

    expect(page).to have_no_css("ul")
  end

  it "lists the videos" do
    create(:video, category: individual_category, name: "Final", url: "https://youtu.be/x")

    render_inline(described_class.new(individual_category: individual_category))

    expect(page).to have_css("ul li", text: "Final")
  end
end
