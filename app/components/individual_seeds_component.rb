# frozen_string_literal: true

# The seeding panel of an individual category's admin page: the seeded
# participants in seed order, a select to seed another, and the reminder that
# seeds only take effect on the next Generate pools.
#
# Lists only the seeded. A category can hold 60 participants and typically has
# 4 seeds, so a full list would be a long panel of empty fields.
#
# The root element always renders (even with no seeds) so a Turbo Stream
# replace always has a target after the last seed is removed.
class IndividualSeedsComponent < ViewComponent::Base
  def initialize(category:)
    @category = category
  end

  private attr_reader :category

  # Both lists are slices of the same set, so it is loaded once.
  private def participations
    @participations ||= category.participations.includes(kenshi: :club).to_a
  end

  private def seeded
    @seeded ||= Participation.in_seed_order(participations)
  end

  private def unseeded
    @unseeded ||= participations.reject(&:seeded?)
      .sort_by { |participation| participation.full_name.to_s }
  end

  private def positions
    (1..seeded.size).to_a
  end

  # What the add select sends: the position a newly seeded participant takes.
  private def next_position
    seeded.size + 1
  end

  # Either flag closes the seeding: on a pooled category the seeds drive the
  # draw, on a bracket-only one they drive the byes and the protected bracket
  # positions. Matches guard_frozen_seeds! on the server. Admin-only by
  # construction, so there is no `admin` to combine with.
  private def seeds_editable? = helpers.pool_formation_editable?(category)

  private def panel_data
    return {} unless seeds_editable?

    {controller: "seed-order", seed_order_next_position_value: next_position}
  end

  private def dom_id_for_seeds
    "individual_seeds_#{category.id}"
  end

  private def seed_url(participation)
    helpers.admin_individual_category_seed_path(category, participation)
  end
end
