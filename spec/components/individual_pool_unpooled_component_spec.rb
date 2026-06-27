# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndividualPoolUnpooledComponent, type: :component do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3) }

  def member(pool: nil, position: nil)
    create(:participation, category: category, kenshi: create(:kenshi, cup: cup),
      pool_number: pool, pool_position: position)
  end

  it "lists only unpooled members, draggable, with an add-to select" do
    member(pool: 1, position: 1)
    late = member

    render_inline(described_class.new(category: category))

    expect(page).to have_text("Unpooled participants")
    expect(page).to have_css("li.pool-unpooled__team[data-participation-id='#{late.id}']")
    expect(page).to have_css("li[data-participation-id='#{late.id}'] .pool-unpooled__grip[draggable='true']")
  end

  it "offers each existing pool plus a New pool option in the select" do
    member(pool: 1, position: 1)
    member(pool: 2, position: 1)
    member

    render_inline(described_class.new(category: category))

    expect(page).to have_css("option[value='1']", text: "Pool 1")
    expect(page).to have_css("option[value='2']", text: "Pool 2")
    expect(page).to have_css("option[value='3']", text: "New pool (Pool 3)")
  end

  it "stays visible as a drop zone even when no members are unpooled" do
    member(pool: 1, position: 1)

    render_inline(described_class.new(category: category))

    expect(page).to have_css("#individual_pool_unpooled_#{category.id}.pool-unpooled")
    expect(page).to have_text("Unpooled participants")
    expect(page).to have_css("[data-action*='drop->pool-membership#dropUnpool']")
  end
end
