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
class SeedOrderMove
  def initialize(participation:, to_position:)
    @participation = participation
    @category = participation.category
    @to_position = to_position.presence&.to_i
  end

  def call
    Participation.transaction do
      participation.update!(seed: nil) if to_position.nil?
      target_order.each_with_index do |member, index|
        next if member.seed == index + 1

        member.update!(seed: index + 1)
      end
    end
    target_order
  end

  private attr_reader :participation, :category, :to_position

  private def target_order
    @target_order ||= begin
      rest = current_order.reject { |member| member.id == participation.id }
      to_position.nil? ? rest : rest.insert(insert_index(rest), participation)
    end
  end

  # A target outside the list clamps into range rather than raising: the panel
  # can race a concurrent unseed, and landing at an end is the harmless
  # reading.
  private def insert_index(rest)
    to_position.clamp(1, rest.size + 1) - 1
  end

  private def current_order
    category.participations.where.not(seed: nil)
      .sort_by { |member| [member.seed, member.id] }
  end
end
