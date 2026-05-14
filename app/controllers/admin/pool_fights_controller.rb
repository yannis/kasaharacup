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
      attrs = tiebreaker_params(category).merge(tiebreaker: true)

      unless pool_membership_valid?(category, attrs)
        head :unprocessable_content
        return
      end

      fight = category.fights.create(attrs)
      if fight.persisted?
        respond_with_pool(category, fight.pool_number, notice: "Tiebreaker created.")
      else
        head :unprocessable_content
      end
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

    def reset
      category = IndividualCategory.find(params[:id])
      pool_number = Integer(params.fetch(:pool_number))
      category.pool_fights.where(pool_number: pool_number).destroy_all
      respond_with_pool(category, pool_number, notice: "Pool fights cleared.")
    end

    private def tiebreaker_params(category)
      permitted = params.expect(pool_fight: [:pool_number, :fighter_1_id, :fighter_2_id]).to_h
      pool_number = permitted[:pool_number].to_i
      max_number = category.pool_fights.where(pool_number: pool_number).maximum(:number).to_i
      permitted.merge(fighter_type: "Kenshi", number: max_number + 1)
    end

    private def pool_membership_valid?(category, attrs)
      pool_kenshi_ids = category.participations
        .where(pool_number: attrs[:pool_number])
        .pluck(:kenshi_id)
      [attrs[:fighter_1_id], attrs[:fighter_2_id]].all? do |id|
        pool_kenshi_ids.include?(id.to_i)
      end
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
