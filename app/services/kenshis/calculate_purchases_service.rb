# frozen_string_literal: true

module Kenshis
  class CalculatePurchasesService
    def initialize(kenshi:)
      @kenshi = kenshi
      @cup = @kenshi.cup
    end

    def call
      purchases = @kenshi.purchases
      participations = @kenshi.participations

      products = []
      participation_types = participations.pluck(:category_type).uniq
      participations.find_each do |participation|
        if participation_types.count > 1
          purchases.where(product: participation_product(participation)).destroy_all
          product = participation_full_product(participation)
        else
          product = participation_product(participation)
        end
        next unless product

        purchases.find_or_create_by!(product: product)
        products << product
      end
      cup_products = [
        @cup.product_individual_junior_id, @cup.product_individual_adult_id, @cup.product_team_id,
        @cup.product_full_junior_id, @cup.product_full_adult_id
      ]
      purchases.where(product: cup_products).where.not(product: products).destroy_all
    end

    private def participation_product(participation)
      if participation.category.is_a? TeamCategory
        @cup.product_team
      elsif participation.category.is_a? IndividualCategory
        if @kenshi.junior?
          @cup.product_individual_junior
        else
          @cup.product_individual_adult
        end
      end
    end

    private def participation_full_product(participation)
      if @kenshi.junior?
        @cup.product_full_junior
      else
        @cup.product_full_adult
      end
    end
  end
end
