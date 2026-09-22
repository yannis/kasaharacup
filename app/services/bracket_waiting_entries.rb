# frozen_string_literal: true

# The entries a category expects, minus the entries its round-1 slots hold:
# what the admin has pulled out of the tree and not yet put back.
#
# Derived on every read, never stored. Nothing to migrate and nothing to drift,
# and two consequences that are both wanted: a pool created or a competitor
# registered after the draw turns up here by itself, where today it needs a
# force rebuild; and a force rebuild empties the area by re-placing everyone.
#
# One consequence that is merely accepted: an entry is findable here only while
# it is in the EXPECTED set. Lowering out_of_pool after a draw, or deleting a
# pool, strands whatever the tree still holds from the old shape — it can be
# dragged out but not back, and force rebuild is the answer those changes
# already needed.
class BracketWaitingEntries
  def self.for(category) = new(category).call

  def initialize(category)
    @category = category
  end

  def call
    expected.reject { |entry| placed_keys.include?(entry.key) }
  end

  private attr_reader :category

  # Descriptor-seeded or pool-less is decided by what the SLOTS carry, not by
  # category.bracket_only?. The two come apart exactly where
  # EncounterTeamSwap.ineligibility_reason used to refuse: lowering pool_size to
  # 1 makes a category bracket_only? while its round-1 slots still hold the
  # previous draw's descriptors. Keyed on the flag, the expected set would be
  # competitors-by-id against a placed set of descriptors, nothing would
  # subtract, and the whole field would show as waiting beside a full tree.
  private def expected
    descriptor_seeded? ? expected_from_pools : expected_from_competitors
  end

  private def descriptor_seeded?
    round_one.any? do |record|
      BracketSlots::SLOTS.any? { |slot| record.slot_entry(slot)&.descriptor? }
    end
  end

  private def expected_from_pools
    (1..category.out_of_pool.to_i).flat_map { |rank|
      pool_slots.pool_numbers.map do |pool_number|
        BracketEntry.for(pool_number: pool_number, pool_rank: rank,
          competitor: pool_slots.competitor_at(pool_number, rank))
      end
    }.compact
  end

  private def expected_from_competitors
    competitors.map do |competitor|
      BracketEntry.for(pool_number: nil, pool_rank: nil, competitor: competitor)
    end
  end

  # A pool-less bracket is a team category's alone — IndividualCategoryBracketBuilder
  # builds every slot from a pool descriptor — but read the association rather
  # than assuming it, so a future pool-less individual draw does not silently
  # return nothing.
  private def competitors
    if category.is_a?(TeamCategory)
      category.teams.to_a
    else
      category.participations.includes(:kenshi).filter_map(&:kenshi)
    end
  end

  private def placed_keys
    @placed_keys ||= round_one.flat_map { |record|
      BracketSlots::SLOTS.filter_map { |slot| record.slot_entry(slot)&.key }
    }.to_set
  end

  # with_slot_competitors, not a bare where: #placed_keys reads a slot entry for
  # every slot, and each one resolves its competitor. Without it that is one
  # query per slot, which is what the admin page's query-count guard catches.
  private def round_one
    @round_one ||= category.bracket_records.with_slot_competitors.where(round: 1).to_a
  end

  private def pool_slots
    @pool_slots ||= CategoryPoolSlots.new(category)
  end
end
