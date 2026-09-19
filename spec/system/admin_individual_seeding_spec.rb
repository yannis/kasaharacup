# frozen_string_literal: true

require "rails_helper"

describe "Admin individual category seeding", :js do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }
  let(:admin) { create(:user, :admin) }

  def participant(name, seed: nil)
    kenshi = create(:kenshi, cup: cup, first_name: name, last_name: "X")
    create(:participation, category: category, kenshi: kenshi, seed: seed)
  end

  def seed_order
    category.participations.where.not(seed: nil).order(:seed).map { |p| p.kenshi.first_name }
  end

  it "reorders the seeds by dragging one onto the position it should take" do
    participant("Aaa", seed: 1)
    participant("Bbb", seed: 2)
    participant("Ccc", seed: 3)

    signin_and_visit(admin, admin_individual_category_path(category))

    third_grip = find(".seed-panel__row[data-position='3'] .seed-panel__grip")
    first_row = find(".seed-panel__row[data-position='1']")
    third_grip.drag_to(first_row, html5: true)

    # Wait for the Turbo Stream to replace the panel with the new numbering.
    expect(page).to have_css(".seed-panel__row[data-position='1']", text: "Ccc")
    expect(seed_order).to eq %w[Ccc Aaa Bbb]
  end

  it "seeds a participant from the add select" do
    participant("Aaa", seed: 1)
    participant("Ddd")

    signin_and_visit(admin, admin_individual_category_path(category))

    find(".seed-panel__add-select").select("Ddd X")

    expect(page).to have_css(".seed-panel__row[data-position='2']", text: "Ddd")
    expect(seed_order).to eq %w[Aaa Ddd]
  end

  it "unseeds from the ✕ button and closes the gap" do
    participant("Aaa", seed: 1)
    participant("Bbb", seed: 2)

    signin_and_visit(admin, admin_individual_category_path(category))

    within(".seed-panel__row[data-position='1']") { click_button "✕" }

    expect(page).to have_css(".seed-panel__row[data-position='1']", text: "Bbb")
    expect(seed_order).to eq %w[Bbb]
  end
end
