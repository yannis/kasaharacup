# frozen_string_literal: true

module Admin
  module Cups
    # The cup-level shortcut (R13): freeze, or unfreeze, every category of one
    # cup at once. Shared by the pools and bracket controllers, which differ
    # only in which flag they carry.
    #
    # Categories with nothing to freeze are skipped rather than counted as
    # failures — an undrawn category or a bracket-only one's absent pool phase
    # is the ordinary case mid-setup, not an error. The flash reports both
    # numbers so the organizer can tell "all done" from "half of them are not
    # drawn yet".
    #
    # No Turbo Stream response. This is a full-page action from the cup page,
    # which is not a live-editing surface; the per-category endpoints are where
    # the broadcasts matter.
    module FreezeAll
      extend ActiveSupport::Concern

      private def apply_to_all(freeze:)
        affected = 0
        skipped = 0

        cup.transaction do
          categories.each do |category|
            unless applicable?(category, freeze: freeze)
              skipped += 1
              next
            end

            freeze ? freeze_one(category) : unfreeze_one(category)
            affected += 1
          end
        end

        redirect_to admin_cup_path(cup),
          notice: t("admin.freezes.all.#{freeze ? "frozen" : "unfrozen"}.#{flag}",
            count: affected, skipped: skipped)
      end

      # By YEAR, not by id: Cup#to_param returns the year, so that is what the
      # path helper puts in :cup_id. ActiveAdmin's own cup page resolves it the
      # same way (app/admin/cup.rb's find_resource).
      private def cup = @cup ||= Cup.where(year: params.expect(:cup_id)).first!

      # Both category types, in one list: the cup page reasons about "every
      # category", not about the two tables behind them.
      private def categories = cup.individual_categories.to_a + cup.team_categories.to_a

      # Freezing skips what has nothing to freeze; unfreezing skips what is not
      # frozen, so the flash counts the categories the press actually changed
      # rather than every category of the cup, and no untouched record is run
      # through a pointless validation pass.
      private def applicable?(category, freeze:)
        freeze ? freezable?(category) : frozen?(category)
      end

      private def freezable?(category)
        (flag == :bracket) ? category.bracket_freezable? : category.pools_freezable?
      end

      private def frozen?(category)
        (flag == :bracket) ? category.bracket_frozen? : category.pools_frozen?
      end

      private def freeze_one(category)
        (flag == :bracket) ? category.freeze_bracket! : category.freeze_pools!
      end

      private def unfreeze_one(category)
        (flag == :bracket) ? category.unfreeze_bracket! : category.unfreeze_pools!
      end
    end
  end
end
