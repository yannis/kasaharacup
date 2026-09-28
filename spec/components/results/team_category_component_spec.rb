# frozen_string_literal: true

require "rails_helper"

RSpec.describe Results::TeamCategoryComponent, type: :component do
  let(:team_category) { create(:team_category) }

  it "leaves out the ranking and attachments when there are none" do
    create(:team, team_category: team_category)

    render_inline(described_class.new(team_category: team_category))

    expect(page).to have_no_css("dl")
    expect(page).to have_no_css("ul")
  end

  it "lists the ranked teams without an empty attachments box" do
    team = create(:team, team_category: team_category, rank: 1)

    render_inline(described_class.new(team_category: team_category))

    expect(page).to have_css("dt", text: "1. #{team.name}")
    expect(page).to have_no_css("ul")
  end

  it "lists the videos" do
    create(:video, category: team_category, name: "Final", url: "https://youtu.be/x")

    render_inline(described_class.new(team_category: team_category))

    expect(page).to have_css("ul li", text: "Final")
  end
end
