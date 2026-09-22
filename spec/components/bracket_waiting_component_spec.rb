# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketWaitingComponent, type: :component do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }

  before do
    (1..2).each do |pool|
      (1..2).each { |rank| create(:team, team_category: category, pool_number: pool, pool_rank: rank) }
    end
    TeamCategoryBracketBuilder.new(category).call
  end

  def round_one = category.bracket_encounters.where(round: 1).order(:position).to_a

  # The TeamPoolUnpooledComponent rule: the root always renders, so a Turbo
  # replace always has a target after the last entry is dragged back in.
  it "renders its container even with nothing waiting" do
    render_inline(described_class.new(category: category))

    expect(page).to have_css "##{described_class.dom_id_for(category)}"
    expect(page).to have_text(/Drag an entry here/i)
  end

  it "lists a pulled entry with its label and a grip" do
    unit = round_one.first
    pulled = unit.slot_entry(1)
    unit.clear_slot(1)

    render_inline(described_class.new(category: category.reload))

    expect(page).to have_text pulled.label
    expect(page).to have_css ".bracket-waiting__grip"
  end

  it "names the competitor behind the descriptor" do
    unit = round_one.first
    team = unit.slot_entry(1).competitor
    unit.clear_slot(1)

    render_inline(described_class.new(category: category.reload))

    expect(page).to have_text team.name
  end

  it "offers every slot that can receive the entry, each carrying its expected entry" do
    unit = round_one.first
    unit.clear_slot(1)

    render_inline(described_class.new(category: category.reload))

    expect(page).to have_css ".bracket-waiting__select option", minimum: 2
    expect(page).to have_css ".bracket-waiting__select option[data-expected-entry='']"
  end

  it "shows no affordance at all on a frozen bracket" do
    round_one.first.clear_slot(1)
    category.update!(bracket_frozen_at: Time.current)

    render_inline(described_class.new(category: category.reload))

    expect(page).to have_no_css ".bracket-waiting__grip"
    expect(page).to have_no_css ".bracket-waiting__select"
  end
end
