# frozen_string_literal: true

# The seeding panel of an individual category's admin page: the seeded
# participants in seed order, a select to seed another, and the reminder that
# seeds only take effect on the next Smart pool reset.
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

  # [seed, id] — the tie-break BracketOnlySeeder uses, so a list left
  # non-contiguous by a destroyed participation still reads in a stable order.
  private def seeded
    @seeded ||= category.participations.includes(kenshi: :club)
      .where.not(seed: nil).sort_by { |participation| [participation.seed, participation.id] }
  end

  private def unseeded
    @unseeded ||= category.participations.includes(kenshi: :club)
      .where(seed: nil).sort_by { |participation| participation.full_name.to_s }
  end

  private def positions
    (1..seeded.size).to_a
  end

  # What the add select sends: the position a newly seeded participant takes.
  private def next_position
    seeded.size + 1
  end

  private def dom_id_for_seeds
    "individual_seeds_#{category.id}"
  end

  private def seed_url(participation)
    helpers.admin_individual_category_seed_path(category, participation)
  end
end
