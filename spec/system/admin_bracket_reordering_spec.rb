# frozen_string_literal: true

require "rails_helper"

describe "Admin bracket reordering", :js do
  let(:cup) { create(:cup) }
  let(:admin) { create(:user, :admin) }

  def slot_selector(record, slot) = "[data-slot-id='#{record.id}-#{slot}']"

  shared_examples "a reorderable bracket" do
    it "swaps two round-1 entries by dragging one slot onto another" do
      first, second = round_one
      moving_out = first.slot_entry(1)
      moving_in = second.slot_entry(1)

      signin_and_visit(admin, category_path)

      find("#{slot_selector(first, 1)} .competition-tree__grip")
        .drag_to(find(slot_selector(second, 1)), html5: true)

      # The response carries the redrawn tree, so wait on the rendered label
      # before touching the database, or the assertion races the request.
      within(slot_selector(second, 1)) { expect(page).to have_content moving_out.label }
      expect(first.reload.slot_entry(1).key).to eq moving_in.key
      expect(second.reload.slot_entry(1).key).to eq moving_out.key
    end

    it "takes an entry out to the waiting area and leaves the partner a bye" do
      first, = round_one
      pulled = first.slot_entry(1)
      survivor = first.slot_entry(2)

      signin_and_visit(admin, category_path)

      find("#{slot_selector(first, 1)} .competition-tree__grip")
        .drag_to(find(".bracket-waiting"), html5: true)

      within(".bracket-waiting") { expect(page).to have_content pulled.label }
      expect(first.reload).to be_bye
      expect(first.slot_entry(first.bye_slot).key).to eq survivor.key
    end

    it "drags a waiting entry back onto the bye's drop strip" do
      first, = round_one
      pulled = first.slot_entry(1)
      first.clear_slot(1)

      signin_and_visit(admin, category_path)

      find(".bracket-waiting__grip")
        .drag_to(find("#{slot_selector(first, 1)}.competition-tree__bye-drop"), html5: true)

      expect(page).to have_no_css ".bracket-waiting__grip"
      expect(first.reload.slot_entry(1).key).to eq pulled.key
    end

    it "moves an entry with no pointer, through the slot's select" do
      first, second = round_one
      moving_out = first.slot_entry(1)
      destination = second.slot_entry(1)

      signin_and_visit(admin, category_path)

      within(slot_selector(first, 1)) do
        find(".competition-tree__move-select").find(:option, text: /#{Regexp.escape(destination.label)}/).select_option
      end

      within(slot_selector(second, 1)) { expect(page).to have_content moving_out.label }
      expect(second.reload.slot_entry(1).key).to eq moving_out.key
    end

    it "removes and re-places an entry with no pointer, through the selects" do
      first, = round_one
      pulled = first.slot_entry(1)

      signin_and_visit(admin, category_path)

      within(slot_selector(first, 1)) do
        find(".competition-tree__move-select").find(:option, text: "Remove from bracket").select_option
      end
      within(".bracket-waiting") { expect(page).to have_content pulled.label }

      within(".bracket-waiting") do
        find(".bracket-waiting__select").find(:option, text: /empty/).select_option
      end

      expect(page).to have_no_css ".bracket-waiting__grip"
      expect(BracketWaitingEntries.for(category.reload)).to be_empty
    end
  end

  context "on a team category" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2, team_size: 3) }

    before do
      (1..2).each do |pool|
        (1..2).each do |rank|
          team = create(:team, team_category: category, pool_number: pool, pool_rank: rank)
          create_list(:kenshi, 3, cup: cup).each do |kenshi|
            create(:participation, category: category, team: team, kenshi: kenshi)
          end
        end
      end
      TeamCategoryBracketBuilder.new(category).call
    end

    def round_one = category.bracket_encounters.where(round: 1).order(:position).to_a
    def category_path = admin_team_category_path(category)

    it_behaves_like "a reorderable bracket"

    it "offers no grip on an encounter that already has a result" do
      first, = round_one
      first.update!(winner: first.team_1)

      signin_and_visit(admin, category_path)

      expect(page).to have_no_css("#{slot_selector(first, 1)} .competition-tree__grip")
    end

    # Regression: merely OPENING a panel used to withdraw the slot's controls,
    # because the auto-seed confirms both lineups and the old eligibility bar
    # read a confirmed lineup as work in progress.
    #
    # Asserted on what the page shows rather than on lineup_1_set?: whether the
    # seed confirms anything depends on there being an earlier encounter to
    # suggest an order from, which a freshly drawn bracket has not got. The
    # flag-level half is pinned deterministically in the component spec
    # ("still renders grips once the lineups have been auto-seeded").
    it "keeps a slot movable after its panel has been opened" do
      first, = round_one
      signin_and_visit(admin, category_path)

      find("a[href='#{admin_team_category_encounter_path(category, first)}']").click
      expect(page).to have_css(".encounter__close-panel")
      # Wait for the panel's bouts to land, so the seed POST has completed.
      expect(page).to have_css(".pool-match__grip", minimum: 2)

      expect(page).to have_css("#{slot_selector(first, 1)} .competition-tree__grip")
      expect(page).to have_css("#{slot_selector(first, 1)} .competition-tree__move-select")
    end

    # The server owns the confirm decision now: it answers 422 with
    # confirm: true and the client asks, where the old panel form baked a
    # verdict per option into the page at render time.
    it "asks before a move that would discard a hand-entered order" do
      first, second = round_one
      first.update!(lineup_1_set: true, lineup_1_set_by_admin: true)
      moving_in = second.slot_entry(1)

      signin_and_visit(admin, category_path)

      accept_confirm(/encounter #{first.number}/) do
        find("#{slot_selector(second, 1)} .competition-tree__grip")
          .drag_to(find(slot_selector(first, 1)), html5: true)
      end

      within(slot_selector(first, 1)) { expect(page).to have_content moving_in.label }
      expect(first.reload.slot_entry(1).key).to eq moving_in.key
    end
  end

  context "on an individual category" do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }

    before do
      (1..2).each do |pool|
        (1..2).each do |rank|
          create(:participation, category: category, pool_number: pool, pool_position: rank, pool_rank: rank)
        end
      end
      IndividualCategoryBracketBuilder.new(category).call
    end

    def round_one = category.bracket_fights.where(round: 1).order(:position).to_a
    def category_path = admin_individual_category_path(category)

    it_behaves_like "a reorderable bracket"
  end
end
