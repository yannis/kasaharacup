# frozen_string_literal: true

# One interface over the two column families a round-1 bracket slot lives in —
# Encounter's team_N_id / team_N_pool_number / team_N_pool_rank and Fight's
# fighter_N_* — so BracketSlotMove can be written once for both bracket kinds.
#
# BracketDisplayNumbering is the precedent: it serves both record types through
# a small published interface rather than being written twice and drifting.
#
# Includers define:
#   SLOT_PREFIX                   "team" / "fighter"
#   slot_extra_attributes(entry)  columns the competitor id drags along
#                                 (Fight's shared polymorphic fighter_type)
#   invalidate_slot_matchup       discard the stale matchup after a re-resolve
#   refresh_child_slot_from_bye   what a unit owes its child when its bye-ness
#                                 changes (a no-op on Fight)
#   children                      public
# and already answer #bye?, #bye_slot and #unscored?.
module BracketSlots
  extend ActiveSupport::Concern

  SLOTS = [1, 2].freeze

  def slot_entry(slot)
    BracketEntry.for(
      pool_number: self[slot_column(slot, :pool_number)],
      pool_rank: self[slot_column(slot, :pool_rank)],
      competitor: public_send(:"#{self.class::SLOT_PREFIX}_#{slot}")
    )
  end

  # NOT `competitor.present?`. A slot holding a pool label with nobody resolved
  # into it yet is occupied — both models already say exactly this, privately,
  # as #slot_present?, which is what #bye_slot is built on. Read it off the
  # competitor instead and a pooled bracket drawn before the pools finish is a
  # tree of byes.
  def slot_occupied?(slot)
    slot_entry(slot).present?
  end

  def entry_slot_for(key)
    SLOTS.detect { |slot| slot_entry(slot)&.key == key }
  end

  private def slot_column(slot, suffix)
    :"#{self.class::SLOT_PREFIX}_#{slot}_#{suffix}"
  end
end
