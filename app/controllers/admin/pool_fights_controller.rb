# frozen_string_literal: true

module Admin
  class PoolFightsController < BaseController
    def generate
      category = IndividualCategory.find(params[:id])
      PoolFightGenerator.new(category).call
      redirect_to admin_individual_category_path(category),
        notice: t(".notice")
    end

    def create
      category = IndividualCategory.find(params[:individual_category_id])
      permitted = params.expect(pool_fight: [:pool_number, :fighter_1_id, :fighter_2_id])

      unless tiebreaker_fighters_valid?(category, permitted)
        head :unprocessable_content
        return
      end

      fight = category.with_lock do
        max_number = category.pool_fights.where(pool_number: permitted[:pool_number]).maximum(:number).to_i
        category.fights.create!(
          pool_number: permitted[:pool_number],
          fighter_1_id: permitted[:fighter_1_id],
          fighter_2_id: permitted[:fighter_2_id],
          fighter_type: "Kenshi",
          number: max_number + 1,
          tiebreaker: true
        )
      end
      respond_with_pool(category, fight.pool_number, notice: "Tiebreaker created.")
    rescue ActiveRecord::RecordInvalid
      head :unprocessable_content
    end

    def update
      category = IndividualCategory.find(params[:individual_category_id])
      fight = category.pool_fights.find(params[:id])
      fight.assign_attributes(outcome_attributes)
      fight.save!
      respond_with_pool(category, fight.pool_number, notice: "Pool fight updated.")
    end

    def destroy
      category = IndividualCategory.find(params[:individual_category_id])
      fight = category.pool_fights.find(params[:id])

      unless fight.tiebreaker
        redirect_to admin_individual_category_path(category),
          alert: t(".alert")
        return
      end

      pool_number = fight.pool_number
      fight.destroy!
      respond_with_pool(category, pool_number, notice: "Tiebreaker removed.")
    end

    def regenerate
      category = IndividualCategory.find(params[:id])
      pool_number = Integer(params.fetch(:pool_number))
      category.transaction do
        category.pool_fights.where(pool_number: pool_number).destroy_all
        PoolFightGenerator.new(category, pool_number: pool_number).call
      end
      respond_with_pool(category, pool_number, notice: "Pool fights regenerated.")
    end

    private def tiebreaker_fighters_valid?(category, permitted)
      fighter_1_id = permitted[:fighter_1_id].to_i
      fighter_2_id = permitted[:fighter_2_id].to_i
      return false if fighter_1_id <= 0 || fighter_2_id <= 0
      return false if fighter_1_id == fighter_2_id

      pool_kenshi_ids = category.participations
        .where(pool_number: permitted[:pool_number])
        .pluck(:kenshi_id)
      [fighter_1_id, fighter_2_id].all? { |id| pool_kenshi_ids.include?(id) }
    end

    private def outcome_attributes
      raw = params.expect(pool_fight: [:winner_id, :draw])
      winner_id = raw[:winner_id].presence
      draw = ActiveModel::Type::Boolean.new.cast(raw[:draw])

      if draw
        {winner_id: nil, draw: true}
      else
        {winner_id: winner_id, draw: false}
      end
    end
  end
end
