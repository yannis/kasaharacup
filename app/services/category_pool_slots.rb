# frozen_string_literal: true

# Who is currently pool N's rank-R competitor, for either category kind.
#
# Extracted from the two bracket builders, which each had a private copy, so
# that BracketWaitingEntries can ask the same question. A second copy would
# eventually disagree with the one the re-resolve uses, and the symptom would be
# an entry showing as waiting while it sits in the tree.
#
# Loads once per instance: a build asks for every slot, and the waiting set asks
# for every slot again.
class CategoryPoolSlots
  def initialize(category)
    @category = category
  end

  def competitor_at(pool_number, pool_rank)
    by_slot[[pool_number, pool_rank]]
  end

  # Every pool the category HAS, whether or not anyone in it is ranked yet.
  # Deliberately not derived from the rank-indexed map above: a bracket drawn
  # before the standings land has pools and no ranks, and both builders need
  # its shape anyway — they create the slots with descriptors and no payload.
  def pool_numbers
    @pool_numbers ||= pooled_scope.where.not(pool_number: nil)
      .distinct.pluck(:pool_number).sort
  end

  def competitors
    by_slot.values
  end

  private attr_reader :category

  private def by_slot
    @by_slot ||= pooled_records.each_with_object({}) do |record, index|
      index[[record.pool_number, record.pool_rank]] = competitor_for(record)
    end
  end

  # A team IS its own competitor; a participation stands in for its kenshi,
  # which is what a Fight's fighter column holds.
  private def competitor_for(record)
    record.is_a?(Participation) ? record.kenshi : record
  end

  private def pooled_records
    pooled_scope.includes(competitor_association)
      .where.not(pool_number: nil).where.not(pool_rank: nil)
  end

  private def pooled_scope
    category.is_a?(TeamCategory) ? category.teams : category.participations
  end

  # Nothing to preload on a team, which is its own competitor.
  private def competitor_association
    category.is_a?(TeamCategory) ? [] : :kenshi
  end
end
