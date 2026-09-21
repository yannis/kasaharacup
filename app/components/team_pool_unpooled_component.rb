# frozen_string_literal: true

# Lists a pooled category's late-registering teams (pool_number nil) so an admin
# can add each to an existing pool or split it into a new one — by dragging the
# row onto a pool card (the pool-membership Stimulus controller) or via the
# per-row "Add to…" select. The root element always renders (even with no
# unpooled teams) so a Turbo Stream replace always has a target after a team is
# added and drops off the list.
class TeamPoolUnpooledComponent < ViewComponent::Base
  include ActionView::RecordIdentifier

  def initialize(team_category:)
    @team_category = team_category
  end

  private attr_reader :team_category

  private def teams
    @teams ||= team_category.teams.where(pool_number: nil).order(:name)
  end

  private def pool_numbers
    @pool_numbers ||= team_category.team_pools.map(&:number)
  end

  # The select's "New pool" option targets a pool number no team holds yet;
  # TeamPoolMove treats that as a freshly-created pool.
  private def next_pool_number
    (pool_numbers.max || 0) + 1
  end

  # Admin-only by construction (nothing renders this publicly), so the freeze
  # flags alone decide. Either one closes the formation: a frozen draw refuses
  # the move, and a frozen bracket refuses it too because the move would clear
  # the tree (R5).
  private def pool_editable? = helpers.pool_formation_editable?(team_category)

  private def drop_zone_data
    return {} unless pool_editable?

    {controller: "pool-membership",
     action: "dragover->pool-membership#dragOver " \
       "dragleave->pool-membership#dragLeave drop->pool-membership#dropUnpool"}
  end

  private def dom_id_for_unpooled
    "team_pool_unpooled_#{team_category.id}"
  end

  private def move_url(team)
    helpers.admin_team_category_pool_membership_path(team_category, team)
  end
end
