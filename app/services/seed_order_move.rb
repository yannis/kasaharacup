# frozen_string_literal: true

# Sets, moves or clears one participation's seed within its individual
# category, and renumbers the category's seeds back to a contiguous 1..N.
# Sibling of PoolMembershipMove: the controller hands over a participation and
# a target and does no arithmetic of its own.
#
# The move is INSERT AT POSITION, not a swap: the participation leaves the
# ordered list and comes back at the target, and everyone between its old and
# new slot shifts one place. The target is the position it ends up holding, so
# a caller dragging downwards needs no off-by-one — dropping seed 2 onto seed
# 4's row makes it seed 4.
#
# The incoming list is not assumed contiguous. Destroying a seeded
# participation in ActiveAdmin leaves a gap (1, 3, 4), and the panel's "add"
# sends N + 1, which can collide with a value already there. Reading the order
# by [seed, id] — the tie-break BracketOnlySeeder uses — and writing 1..N back
# heals both on the next change, instead of either needing a path of its own.
#
# Nothing here touches pools: seeds apply on the next Smart pool reset.
#
# Returns a Result whose status is :noop when the move asked for the order that
# was already in place, so the caller can skip re-rendering and broadcasting —
# the same shape PoolMembershipMove reports.
class SeedOrderMove
  Result = Data.define(:status, :order)

  def initialize(participation:, to_position:)
    @participation = participation
    @category = participation.category
    # Total by construction: nil, "" and anything non-numeric all read as "no
    # target", i.e. unseed. The controller has already turned garbage into a
    # 400, so a value arriving here that is not a position really is an
    # unseed — this only keeps a direct caller from reaching to_i's 0.
    @to_position = Integer(to_position, exception: false)
  end

  def call
    Participation.transaction do
      # The category row is locked for the whole move, and the order is read
      # inside that lock. Read outside it, two admins dragging at the same
      # moment would both plan from the same snapshot and the second write
      # would silently drop the first one's move — invisibly, because the
      # broadcast then "corrects" the first admin's page.
      category.lock!
      order = target_order
      # Both run: an unseed clears one row AND renumbers what is left.
      cleared = clear_seed!
      renumbered = renumber!(order)
      Result.new(status: (cleared || renumbered) ? :ok : :noop, order: order)
    end
  end

  private attr_reader :participation, :category, :to_position

  private def clear_seed!
    return false if to_position || participation.seed.nil?

    write_seed!(participation, nil)
    true
  end

  # Writes 1..N and reports whether any of them was a change.
  private def renumber!(order)
    order.each_with_index.map { |member, index| write_seed!(member, index + 1) }.any?
  end

  # update_columns, not update!: the value is computed here and the only
  # validation on :seed is a numericality this satisfies by construction. A full
  # save would run the record's OWN validations, so a single participation made
  # invalid by a later category edit — narrowing max_age under an already
  # seeded kenshi — would make every seed change in that category raise, with
  # nothing in the panel's generic error banner pointing at the cause.
  private def write_seed!(member, seed)
    return false if member.seed == seed

    member.update_columns(seed: seed)
    true
  end

  # Derived once into a local rather than memoised on the instance: a second
  # call would otherwise replay the first one's plan instead of reading the
  # seeds as they now stand, and silently undo whatever happened in between.
  private def target_order
    rest = current_order.reject { |member| member.id == participation.id }
    return rest if to_position.nil?

    rest.insert(insert_index(rest), participation)
  end

  # A target outside the list clamps into range rather than raising: the panel
  # can race a concurrent unseed, and landing at an end is the harmless
  # reading. Garbage never reaches this — the controller answers 400 for
  # anything that is not blank or a positive integer — so the clamp is only
  # ever closing a gap the list moved under, not rescuing a bad request.
  private def insert_index(rest)
    to_position.clamp(1, rest.size + 1) - 1
  end

  private def current_order
    category.participations.seeded.to_a
  end
end
