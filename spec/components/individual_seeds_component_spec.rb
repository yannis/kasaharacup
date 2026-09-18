# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndividualSeedsComponent, type: :component do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 4) }
  let(:sequence) { (1..).each }

  def participant(seed: nil, grade: "3Dan")
    n = sequence.next
    kenshi = create(:kenshi, cup: cup, grade: grade, first_name: "First#{n}", last_name: "Last#{n}")
    create(:participation, category: category, kenshi: kenshi, seed: seed)
  end

  it "renders its root element even with no seeds, so a stream always has a target" do
    render_inline(described_class.new(category: category))

    expect(page).to have_css("#individual_seeds_#{category.id}")
  end

  it "lists the seeded in seed order, each row draggable and numbered" do
    second = participant(seed: 2)
    first = participant(seed: 1)

    render_inline(described_class.new(category: category))

    rows = page.all(".seed-panel__row")
    expect(rows.size).to eq 2
    expect(rows.first["data-seed-url"]).to include("/seeds/#{first.id}")
    expect(rows.last["data-seed-url"]).to include("/seeds/#{second.id}")
    expect(page).to have_css(".seed-panel__row[data-position='1'] .seed-panel__grip[draggable='true']")
  end

  it "shows each seed's name, club and grade" do
    seeded = participant(seed: 1, grade: "5Dan")

    render_inline(described_class.new(category: category))

    expect(page).to have_text(seeded.full_name)
    expect(page).to have_text(seeded.club.to_s)
    expect(page).to have_text("5Dan")
  end

  it "offers every position in a move select and an unseed button per row" do
    participant(seed: 1)
    participant(seed: 2)

    render_inline(described_class.new(category: category))

    within_row = ".seed-panel__row:first-child"
    expect(page).to have_css("#{within_row} .seed-panel__move-select option[value='1']")
    expect(page).to have_css("#{within_row} .seed-panel__move-select option[value='2']")
    expect(page).to have_css("#{within_row} .seed-panel__unseed")
  end

  it "offers only the unseeded in the add select, by their seed URL" do
    participant(seed: 1)
    unseeded = participant

    render_inline(described_class.new(category: category))

    options = page.all(".seed-panel__add-select option").pluck("value")
    expect(options.compact_blank.size).to eq 1
    expect(options.compact_blank.first).to include("/seeds/#{unseeded.id}")
  end

  it "carries the next free position for the add select" do
    participant(seed: 1)
    participant(seed: 2)
    participant

    render_inline(described_class.new(category: category))

    expect(page).to have_css("[data-seed-order-next-position-value='3']")
  end

  # A seeded participation destroyed in ActiveAdmin leaves a gap behind, and
  # SeedOrderMove reads to_position as a rank into the seeded list. The rows
  # must therefore carry ranks, agreeing with what the move select offers —
  # sending the raw seed would overshoot on a gapped list.
  it "numbers the rows by rank, not by the stored seed, when seeds have a gap" do
    first = participant(seed: 1)
    third = participant(seed: 3)
    fifth = participant(seed: 5)

    render_inline(described_class.new(category: category))

    rows = page.all(".seed-panel__row")
    expect(rows.pluck("data-position")).to eq %w[1 2 3]
    expect(rows.pluck("data-seed-url"))
      .to match [first, third, fifth].map { |p| a_string_including("/seeds/#{p.id}") }
    expect(page.all(".seed-panel__move-select option").pluck("value").compact_blank.uniq).to eq %w[1 2 3]
  end

  it "still offers the add select and the hint with nothing seeded at all" do
    participant

    render_inline(described_class.new(category: category))

    expect(page).to have_css(".seed-panel__add-select")
    expect(page).to have_text("Smart pool reset")
    expect(page).to have_no_css(".seed-panel__row")
  end

  it "says when nothing is seeded yet" do
    participant

    render_inline(described_class.new(category: category))

    expect(page).to have_text("No seeds yet")
  end

  it "says that seeds apply on the next Smart pool reset" do
    render_inline(described_class.new(category: category))

    expect(page).to have_text("Smart pool reset")
  end
end
