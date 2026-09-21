# frozen_string_literal: true

module Admin
  module TeamCategories
    # The category's pool ties as one printable running order (GET). The
    # document is TeamCategoryPoolOrderPdf and the order it prints is
    # PoolEncounterOrder — the same order the match sheets are stacked in.
    #
    # Named for the encounters it orders: "pool order" already means the order
    # of teams *within* a pool (pool_position, SeedPoolOrder).
    class PoolEncounterOrdersController < Admin::BaseController
      def show
        send_pdf TeamCategoryPoolOrderPdf.new(team_category),
          filename: "#{team_category.name}_#{team_category.cup.year}_pool_fight_order"
      end
    end
  end
end
