# frozen_string_literal: true

# Lists a pooled individual category's late-registering participants
# (pool_number nil) so an admin can add each to an existing pool or split it
# into a new one — by dragging the row onto a pool card (the pool-membership
# Stimulus controller) or via the per-row "Add to…" select. The root element
# always renders (even with no unpooled members) so a Turbo Stream replace
# always has a target after a member is added and drops off the list.
#
# Individual analog of TeamPoolUnpooledComponent.
class IndividualPoolUnpooledComponent < ViewComponent::Base
  include ActionView::RecordIdentifier

  def initialize(category:)
    @category = category
  end

  private attr_reader :category

  private def participations
    @participations ||= category.participations.no_pool.includes(:kenshi)
      .sort_by { |participation| participation.full_name.to_s }
  end

  private def pool_numbers
    @pool_numbers ||= category.pools.map(&:number).sort
  end

  # The select's "New pool" option targets a pool number no participant holds
  # yet; PoolMembershipMove treats that as a freshly-created pool.
  private def next_pool_number
    (pool_numbers.max || 0) + 1
  end

  private def dom_id_for_unpooled
    "individual_pool_unpooled_#{category.id}"
  end

  private def move_url(participation)
    helpers.admin_individual_category_pool_membership_path(category, participation)
  end
end
