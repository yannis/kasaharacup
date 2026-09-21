# frozen_string_literal: true

# Pool formation and the elimination bracket are derived structures that
# several admin tools happily rebuild. Once organizers are satisfied with a
# draw — or once all the bracket results are in — freezing says so, and the
# guards refuse the rebuild rather than trusting a confirmation dialog on a
# competition-day screen someone else also has open (issue #1319).
#
# Included through ActsAsCategory, so both IndividualCategory and TeamCategory
# pick it up on the path they already share. ActiveSupport::Concern's dependency
# mechanism carries it to the including class, not to ActsAsCategory itself.
#
# NAMING: there is deliberately no #frozen? and no #freeze here. Those are
# Object methods ActiveRecord relies on — ActiveRecord::Core#frozen? answers
# @attributes.frozen? — and shadowing them breaks dup/clone, readonly handling
# and association writes in ways that surface far from this file.
module Freezable
  extend ActiveSupport::Concern

  included do
    scope :pools_frozen, -> { where.not(pools_frozen_at: nil) }
    scope :bracket_frozen, -> { where.not(bracket_frozen_at: nil) }
  end

  def pools_frozen? = pools_frozen_at.present?

  def bracket_frozen? = bracket_frozen_at.present?

  # Idempotent, because the panel badge shows the timestamp and two organizers
  # pressing the button is ordinary rather than an error: re-freezing must not
  # move the moment the category was settled.
  def freeze_pools!
    update!(pools_frozen_at: Time.current) unless pools_frozen?
  end

  def freeze_bracket!
    update!(bracket_frozen_at: Time.current) unless bracket_frozen?
  end

  def unfreeze_pools! = update!(pools_frozen_at: nil)

  def unfreeze_bracket! = update!(bracket_frozen_at: nil)

  # Hides the freeze button when there is nothing to freeze (R15). Implemented
  # per class because "has pools" differs: participations carry the pool number
  # for an individual category, teams carry it for a team one.
  def pools_freezable? = raise NotImplementedError

  def bracket_freezable? = raise NotImplementedError
end
