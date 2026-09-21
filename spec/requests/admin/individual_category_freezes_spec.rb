# frozen_string_literal: true

require "rails_helper"

# Freezing is a singular resource per surface: POST freezes, DELETE unfreezes.
# The response and the broadcast carry the same set, because the acting admin
# and every other open page have to end up rendering the category the same way.
RSpec.describe "Admin individual category freezes" do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3) }
  let(:admin) { create(:user, :admin) }
  let(:sequence) { (1..).each }

  before { sign_in admin }

  def participant(pool: nil)
    n = sequence.next
    kenshi = create(:kenshi, cup: cup, first_name: "First#{n}", last_name: "Last#{n}")
    create(:participation, category: category, kenshi: kenshi, pool_number: pool)
  end

  def drawn_pools
    2.times { participant(pool: 1) }
    2.times { participant(pool: 2) }
  end

  describe "pools" do
    it "freezes on POST and unfreezes on DELETE" do
      expect { post admin_individual_category_pool_freeze_path(category) }
        .to change { category.reload.pools_frozen? }.from(false).to(true)

      expect { delete admin_individual_category_pool_freeze_path(category) }
        .to change { category.reload.pools_frozen? }.from(true).to(false)
    end

    it "leaves the bracket flag alone" do
      post admin_individual_category_pool_freeze_path(category)

      expect(category.reload).not_to be_bracket_frozen
    end

    it "redirects an HTML request back to the category with a notice" do
      post admin_individual_category_pool_freeze_path(category)

      expect(response).to redirect_to(admin_individual_category_path(category))
      expect(flash[:notice]).to be_present
    end

    # The panel chrome is replaced alongside the panels: without it a second
    # admin's page keeps an active "Freeze" button over read-only pool cards.
    it "replaces the panels and the chrome for a Turbo Stream request" do
      drawn_pools

      post admin_individual_category_pool_freeze_path(category), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("target=\"individual_pools_#{category.id}\"")
      expect(response.body).to include("target=\"individual_pool_unpooled_#{category.id}\"")
      expect(response.body).to include("target=\"individual_seeds_#{category.id}\"")
      expect(response.body).to include("target=\"individual_pools_actions_#{category.id}\"")
    end
  end

  describe "bracket" do
    it "freezes on POST and unfreezes on DELETE" do
      expect { post admin_individual_category_bracket_freeze_path(category) }
        .to change { category.reload.bracket_frozen? }.from(false).to(true)

      expect { delete admin_individual_category_bracket_freeze_path(category) }
        .to change { category.reload.bracket_frozen? }.from(true).to(false)
    end

    it "leaves the pools flag alone" do
      post admin_individual_category_bracket_freeze_path(category)

      expect(category.reload).not_to be_pools_frozen
    end

    # R5: a frozen bracket also closes pool formation, because any membership
    # move clears the tree. So the pool cards have to lose their grips too, and
    # that means this response carries them as well.
    it "replaces the tree, its chrome and the pool surfaces" do
      drawn_pools
      create(:fight, individual_category: category)

      post admin_individual_category_bracket_freeze_path(category), as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("target=\"#{ActionView::RecordIdentifier.dom_id(category, :competition_tree)}\"")
      expect(response.body).to include("target=\"individual_tree_actions_#{category.id}\"")
      expect(response.body).to include("target=\"individual_pools_#{category.id}\"")
    end
  end

  it "redirects a non-admin away" do
    sign_out admin
    sign_in create(:user)

    post admin_individual_category_pool_freeze_path(category)

    expect(response).to have_http_status(:redirect)
    expect(category.reload).not_to be_pools_frozen
  end
end
