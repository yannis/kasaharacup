# frozen_string_literal: true

require "rails_helper"

# End-to-end proof that the freeze reaches the page: the controls disappear
# when a surface is frozen, come back when it is unfrozen, and a drag issued
# from a page opened before the freeze is refused with a reason rather than
# snapping back in silence (R9, R10, R12).
#
# Controls are found by their container and their modifier class rather than
# by label: the admin renders in French, so every label here is a translation.
describe "Admin freeze", :js do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3) }
  let(:admin) { create(:user, :admin) }
  let(:sequence) { (1..).each }

  def participant(pool:)
    n = sequence.next
    kenshi = create(:kenshi, cup: cup, first_name: "First#{n}", last_name: "Last#{n}")
    create(:participation, category: category, kenshi: kenshi, pool_number: pool)
  end

  def drawn_pools
    2.times { participant(pool: 1) }
    2.times { participant(pool: 2) }
  end

  def pools_chrome = "#individual_pools_actions_#{category.id}"

  def tree_chrome = "#individual_tree_actions_#{category.id}"

  it "takes the formation controls off the page and puts them back" do
    drawn_pools

    signin_and_visit(admin, admin_individual_category_path(category))
    expect(page).to have_css(".pool-standings__grip")

    within(pools_chrome) { find(".freeze-control__button--freeze").click }

    # The badge replaces the button, and the grips and move selects are gone —
    # while the rank editor, which records results, stays.
    expect(page).to have_css("#{pools_chrome} .freeze-control__badge")
    expect(page).to have_no_css(".pool-standings__grip")
    expect(page).to have_no_css(".pool-standings__move-select")
    expect(page).to have_css(".pool-standings__editable")
    expect(category.reload).to be_pools_frozen

    accept_confirm { within(pools_chrome) { find(".freeze-control__button--unfreeze").click } }

    expect(page).to have_css(".pool-standings__grip")
    expect(category.reload).not_to be_pools_frozen
  end

  it "takes the bracket's edit controls off the page" do
    drawn_pools
    create(:fight, individual_category: category)

    signin_and_visit(admin, admin_individual_category_path(category))
    expect(page).to have_text("Edit result")

    within(tree_chrome) { find(".freeze-control__button--freeze").click }

    expect(page).to have_css("#{tree_chrome} .freeze-control__badge")
    expect(page).to have_no_text("Edit result")
    expect(page).to have_no_text("Force rebuild")
    expect(category.reload).to be_bracket_frozen
  end

  # The case the whole feature exists for: a second organizer's page, opened
  # before the freeze, still holds working drag handles. The server refuses the
  # move and the client says why (R12).
  it "refuses a drag from a page opened before the freeze, with a reason" do
    drawn_pools

    signin_and_visit(admin, admin_individual_category_path(category))
    expect(page).to have_css(".pool-standings__grip")

    # Frozen elsewhere — this page knows nothing about it yet.
    category.freeze_pools!

    moved = category.participations.where(pool_number: 1).order(:id).first
    grip = find("tr[data-participation-id='#{moved.id}'] .pool-standings__grip")
    destination = all(".pool-card").last

    message = accept_alert { grip.drag_to(destination, html5: true) }

    expect(message).to be_present
    expect(moved.reload.pool_number).to eq 1
  end

  # The bracket half of R12. Three fetch clients other than the pool drag post
  # to guarded endpoints — fight-winner here, plus stream-link and lineup — and
  # all three used to console.error a 403 and return, which reads as a saved
  # result. fight-winner stands in for the set: same three lines, same 403
  # body, and the cheapest fixture that puts one of them on a page.
  it "refuses a bracket result from a page opened before the freeze, with a reason" do
    drawn_pools
    fight = create(:fight, individual_category: category)

    signin_and_visit(admin, admin_individual_category_path(category))
    find(".competition-tree__admin-details summary").click
    radio = first(".competition-tree__point-controls input[type='radio']")

    # Frozen elsewhere — this page knows nothing about it yet. Freezing on the
    # model rather than through the endpoint is what makes it stale: the
    # broadcast that would strip these controls never fires.
    category.freeze_bracket!

    message = accept_alert { radio.click }

    expect(message).to be_present
    expect(fight.reload.winner_id).to be_nil
  end
end
