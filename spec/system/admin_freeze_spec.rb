# frozen_string_literal: true

require "rails_helper"

# End-to-end proof that the freeze reaches the page: the controls disappear
# when a surface is frozen, come back when it is unfrozen, and a drag issued
# from a page opened before the freeze is refused with a reason rather than
# snapping back in silence (R9, R10, R12).
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

  it "takes the formation controls off the page and puts them back" do
    drawn_pools

    signin_and_visit(admin, admin_individual_category_path(category))
    expect(page).to have_css(".pool-standings__grip")

    click_button "Freeze pools"

    # The badge replaces the button, and the grips and move selects are gone —
    # while the rank editor, which records results, stays.
    expect(page).to have_css(".freeze-control__badge")
    expect(page).to have_no_css(".pool-standings__grip")
    expect(page).to have_no_css(".pool-standings__move-select")
    expect(page).to have_css(".pool-standings__editable")
    expect(category.reload).to be_pools_frozen

    accept_confirm { click_button "Unfreeze pools" }

    expect(page).to have_css(".pool-standings__grip")
    expect(category.reload).not_to be_pools_frozen
  end

  it "takes the bracket's edit controls off the page" do
    drawn_pools
    create(:fight, individual_category: category)

    signin_and_visit(admin, admin_individual_category_path(category))
    expect(page).to have_text("Edit result")

    click_button "Freeze bracket"

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
    destination = find(".pool-card", match: :first)

    message = accept_alert { grip.drag_to(destination, html5: true) }

    expect(message).to be_present
    expect(moved.reload.pool_number).to eq 1
  end
end
