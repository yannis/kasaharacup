# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamSeedsComponent, type: :component do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: 3, team_size: 3) }
  let(:sequence) { (1..).each }

  def team(seed: nil)
    create(:team, team_category: category, name: "Team #{sequence.next}", seed: seed)
  end

  it "renders its root element even with no seeds, so a stream always has a target" do
    render_inline(described_class.new(category: category))

    expect(page).to have_css("#team_seeds_#{category.id}")
  end

  it "lists the seeded in seed order, each row draggable and numbered" do
    second = team(seed: 2)
    first = team(seed: 1)

    render_inline(described_class.new(category: category))

    rows = page.all(".seed-panel__row")
    expect(rows.size).to eq 2
    expect(rows.first["data-seed-url"]).to include("/seeds/#{first.id}")
    expect(rows.last["data-seed-url"]).to include("/seeds/#{second.id}")
    expect(rows.pluck("data-position")).to eq %w[1 2]
  end

  # The row's number is its RANK, not the stored seed: ActiveAdmin can destroy a
  # seeded team and leave a gap, and the server reads to_position as a rank.
  it "numbers the rows by rank even when the stored seeds have a gap" do
    team(seed: 1)
    team(seed: 4)

    render_inline(described_class.new(category: category))

    expect(page.all(".seed-panel__number").map(&:text)).to eq %w[1 2]
  end

  it "offers only the unseeded in the add select, by their seed URL" do
    team(seed: 1)
    spare = team

    render_inline(described_class.new(category: category))

    options = page.all(".seed-panel__add-select option[value]").reject { |o| o["value"].empty? }
    expect(options.size).to eq 1
    expect(options.first["value"]).to include("/seeds/#{spare.id}")
    expect(options.first.text).to eq spare.name
  end

  it "carries the next free position for the add select" do
    team(seed: 1)
    team(seed: 2)

    render_inline(described_class.new(category: category))

    expect(page.find(".seed-panel")["data-seed-order-next-position-value"]).to eq "3"
  end

  it "subscribes to its own stream, so a bracket-only page still follows along" do
    render_inline(described_class.new(category: category))

    expect(page).to have_css("turbo-cable-stream-source", visible: :all)
  end

  # A team's telling detail is whether it can field a squad, where the
  # individual panel shows a grade.
  it "shows an incomplete team's roster count" do
    short = team(seed: 1)
    create(:participation, category: category, team: short, kenshi: create(:kenshi, cup: cup))

    render_inline(described_class.new(category: category))

    expect(page.find(".seed-panel__grade").text).to eq "1/3"
  end

  describe "the hint naming when seeds take effect" do
    # Both sides name the same button and both poolers redraw every pool from
    # scratch, so this hint and the individual panel's now say the same thing.
    # What must stay different is the bracket-only branch below, which never
    # runs a pooler at all.
    it "names Generate pools, and warns it redraws, for a pooled category" do
      team(seed: 1)

      render_inline(described_class.new(category: category))

      hint = page.find(".seed-panel__hint").text
      expect(hint).to include("Generate pools")
      expect(hint).to include("manual pool assignments are lost")
    end

    # A bracket-only category never runs the pooler, so pointing at it would be
    # telling the admin to press a button that does nothing for them.
    it "says bracket build for a bracket-only category" do
      category.update!(pool_size: 1)
      team(seed: 1)

      render_inline(described_class.new(category: category))

      hint = page.find(".seed-panel__hint").text
      expect(hint).to include("bracket build")
      expect(hint).not_to include("Generate pools")
    end
  end

  # Twin of the individual panel: either flag closes the seeding.
  describe "when frozen" do
    def panel
      render_inline(described_class.new(category: category)).to_html
    end

    it "drops the seeding controls but keeps the list and the subscription" do
      seeded_team if respond_to?(:seeded_team, true)
      expect(panel).to include("seed-panel")

      category.freeze_pools!

      frozen = panel
      expect(frozen).not_to include("seed-panel__grip")
      expect(frozen).not_to include("seed-panel__add")
      # The subscription must survive, or the category never hears its unfreeze.
      expect(frozen).to include("turbo-cable-stream-source")
    end
  end
end
