# frozen_string_literal: true

# One thing that can sit in a round-1 bracket slot: a pool descriptor ("the
# runner-up of pool 3"), the competitor currently resolved into it, or — before
# the pools have finished — the descriptor alone.
#
# It is the unit the admin drags, and the reason a hand-made layout survives
# "Update bracket": moving an entry moves the descriptor with it, so the next
# build re-resolves each slot from the label the admin put there rather than
# from the label the generator put there.
#
# A plain value object, not a record. Nothing about the waiting area or the
# tree is persisted beyond the three columns these three fields map onto.
class BracketEntry < Data.define(:pool_number, :pool_rank, :competitor)
  # nil rather than an empty entry, so "is this slot occupied?" is
  # `slot_entry(slot).present?` at every call site instead of a predicate that
  # has to be remembered.
  def self.for(pool_number:, pool_rank:, competitor:)
    return if pool_number.blank? && pool_rank.blank? && competitor.blank?

    new(pool_number: pool_number, pool_rank: pool_rank, competitor: competitor)
  end

  # BOTH halves. A row carrying a pool number and no rank is drift, not a
  # descriptor, and resolving it would index the pool lookup with a nil.
  def descriptor?
    pool_number.present? && pool_rank.present?
  end

  def label
    return "#{pool_number}.#{pool_rank}" if descriptor?

    competitor_name.to_s
  end

  # The stable id the client hands back on a drop. The descriptor wins whenever
  # there is one, because that is what the slot re-resolves from — the
  # competitor behind it is this morning's standings and may be someone else by
  # the afternoon.
  #
  # Pool-less brackets exist only for team categories
  # (IndividualCategoryBracketBuilder builds every slot from a pool
  # descriptor), so "kenshi-57" is reachable here but never produced by a real
  # bracket.
  def key
    return "#{pool_number}.#{pool_rank}" if descriptor?
    return if competitor.nil?

    "#{competitor.model_name.singular}-#{competitor.id}"
  end

  # Teams carry a name column; kenshis answer #full_name. The waiting panel and
  # the tree name a competitor their own way (poster names, batched) — this is
  # the fallback for a label with no descriptor behind it.
  def competitor_name
    return if competitor.nil?

    competitor.respond_to?(:name) ? competitor.name : competitor.full_name
  end
end
