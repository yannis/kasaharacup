# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin individual category show page" do
  let(:cup) { create(:cup) }
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "renders the pools panel with the unpooled component when pool_size > 1" do
    category = create(:individual_category, cup: cup, pool_size: 3)
    create(:participation, category: category, kenshi: create(:kenshi, cup: cup),
      pool_number: 1, pool_position: 1)
    create(:participation, category: category, kenshi: create(:kenshi, cup: cup), pool_number: nil)

    get admin_individual_category_path(category)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("individual_pools_#{category.id}")
    expect(response.body).to include("individual_pool_unpooled_#{category.id}")
    expect(response.body).to include("Unpooled participants")
  end

  it "shows the plain unpooled fallback for a non-pooled category (pool_size <= 1)" do
    category = create(:individual_category, cup: cup, pool_size: 1)
    create(:participation, category: category, kenshi: create(:kenshi, cup: cup), pool_number: nil)

    get admin_individual_category_path(category)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("individual_pool_unpooled_#{category.id}")
  end

  it "shows the seeding panel above the pools" do
    category = create(:individual_category, cup: cup, pool_size: 3)
    create(:participation, category: category, kenshi: create(:kenshi, cup: cup),
      pool_number: 1, pool_position: 1)

    get admin_individual_category_path(category)

    expect(response.body).to include("individual_seeds_#{category.id}")
    expect(response.body.index("individual_seeds_#{category.id}"))
      .to be < response.body.index("individual_pools_#{category.id}")
  end

  it "leaves the seeding panel out of a pool-less category" do
    category = create(:individual_category, cup: cup, pool_size: 1)

    get admin_individual_category_path(category)

    expect(response.body).not_to include("individual_seeds_#{category.id}")
  end
end
