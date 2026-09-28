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

  it "draws the bracket after the ranking" do
    create(:team_category, pool_size: 3, out_of_pool: 1).then do |tc|
      2.times { |i| create(:team, team_category: tc, pool_number: i + 1, pool_rank: 1, rank: i + 1) }
      TeamCategoryBracketBuilder.new(tc).call

      render_inline(described_class.new(team_category: tc))
    end

    expect(page).to have_css("div:has(dl) ~ div .competition-tree")
  end
end
