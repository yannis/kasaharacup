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

  # The panel chrome moved out of Arbre into partials so a freeze broadcast can
  # replace it. These pin the links that move down with it: a partial that
  # renders in the controller's view context but not in ActiveAdmin's would
  # otherwise lose them silently.
  describe "panel chrome" do
    it "offers the pool-fight generation link and the freeze control" do
      category = create(:individual_category, cup: cup, pool_size: 3)
      2.times do |i|
        create(:participation, category: category, kenshi: create(:kenshi, cup: cup),
          pool_number: 1, pool_position: i + 1)
      end

      get admin_individual_category_path(category)

      expect(response.body).to include("individual_pools_actions_#{category.id}")
      expect(response.body).to include("Generate pool fights")
      # The control is asserted by its endpoint, not its label: the admin
      # renders in French and the label is a translation.
      expect(response.body).to include(admin_individual_category_pool_freeze_path(category))
    end

    it "offers tree generation before a bracket exists" do
      category = create(:individual_category, cup: cup, pool_size: 3)

      get admin_individual_category_path(category)

      expect(response.body).to include("individual_tree_actions_#{category.id}")
      expect(response.body).to include("Generate tree")
      # Nothing to freeze yet (R15).
      expect(response.body).not_to include(admin_individual_category_bracket_freeze_path(category))
    end

    it "offers update, rebuild and PDF once a bracket exists" do
      category = create(:individual_category, cup: cup, pool_size: 3)
      create(:fight, individual_category: category)

      get admin_individual_category_path(category)

      expect(response.body).to include("Update tree")
      expect(response.body).to include("Force rebuild")
      expect(response.body).to include("Download PDF")
      expect(response.body).to include(admin_individual_category_bracket_freeze_path(category))
    end
  end

  # R10 end to end: the panel chrome and the cards agree about the frozen state
  # on a real page render, not just in isolation.
  describe "when frozen" do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3) }

    before do
      2.times do |i|
        create(:participation, category: category, kenshi: create(:kenshi, cup: cup),
          pool_number: 1, pool_position: i + 1)
      end
      create(:fight, individual_category: category)
    end

    it "drops the formation controls and the smart reset when the pools are frozen" do
      category.freeze_pools!

      get admin_individual_category_path(category)

      expect(response.body).not_to include("pool-standings__grip")
      expect(response.body).not_to include(reset_smart_pools_admin_individual_category_path(category))
      expect(response.body).to include(admin_individual_category_pool_freeze_path(category))
    end

    it "drops the tree rebuild links when the bracket is frozen" do
      category.freeze_bracket!

      get admin_individual_category_path(category)

      expect(response.body).not_to include("Force rebuild")
      expect(response.body).not_to include("Update tree")
      expect(response.body).not_to include("Edit result")
      expect(response.body).to include("Download PDF")
    end

    it "restores everything once unfrozen" do
      category.freeze_pools!
      category.freeze_bracket!
      category.unfreeze_pools!
      category.unfreeze_bracket!

      get admin_individual_category_path(category)

      expect(response.body).to include("pool-standings__grip")
      expect(response.body).to include("Force rebuild")
      expect(response.body).to include("Edit result")
    end
  end
end
