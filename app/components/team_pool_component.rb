# frozen_string_literal: true

class TeamPoolComponent < ViewComponent::Base
  include ActionView::RecordIdentifier

  # `pools` is the category's TeamPool list when a whole page of cards is being
  # rendered, so the page reads the (deliberately unmemoized) team_pools once
  # instead of once per card. nil when a card is broadcast on its own.
  def initialize(team_category:, pool_number:, admin: true, pools: nil)
    @team_category = team_category
    @pool_number = pool_number
    @admin = admin
    @pools = pools
  end

  private attr_reader :team_category, :pool_number, :admin, :pools

  private def encounters
    @encounters ||= team_category.encounters_by_pool_number.fetch(pool_number, [])
  end

  private def dom_id_for_pool
    "team_pool_#{team_category.id}_#{pool_number}"
  end

  # Admin cards are drop targets for the pool-membership drag-and-drop: a team
  # row dragged from another card drops here to join this pool.
  private def container_data
    return {} unless admin

    {
      controller: "pool-membership",
      pool_membership_pool_number_value: pool_number,
      action: "dragover->pool-membership#dragOver " \
        "dragleave->pool-membership#dragLeave drop->pool-membership#drop"
    }
  end
end
