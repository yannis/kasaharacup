# frozen_string_literal: true

module Admin
  class PoolFightsController < BaseController
    def generate
      category = IndividualCategory.find(params.expect(:id))
      PoolFightGenerator.new(category).call
      redirect_to admin_individual_category_path(category),
        notice: t(".notice")
    end

    def create
      category = IndividualCategory.find(params.expect(:individual_category_id))
      permitted = params.expect(pool_fight: [:pool_number, :fighter_1_id, :fighter_2_id])

      unless kettei_sen_fighters_valid?(category, permitted)
        flash.now[:alert] = t(".alert")
        respond_with_pool(category, permitted[:pool_number].to_i)
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
      category = IndividualCategory.find(params.expect(:individual_category_id))
      fight = category.pool_fights.find(params.expect(:id))
      fight.assign_attributes(outcome_attributes)
      fight.save!
      respond_with_pool(category, fight.pool_number, notice: "Pool fight updated.")
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      respond_with_pool(category, fight.pool_number)
    end

    def destroy
      category = IndividualCategory.find(params.expect(:individual_category_id))
      fight = category.pool_fights.find(params.expect(:id))

      unless fight.tiebreaker
        redirect_to admin_individual_category_path(category),
          alert: t(".alert")
        return
      end

      pool_number = fight.pool_number
      fight.destroy!
      respond_with_pool(category, pool_number, notice: "Tiebreaker removed.")
    end

    # Guarded where #generate is not (R2a): this destroy_all's the pool's
    # fights before rebuilding them, so it can alter a frozen formation, while
    # PoolFightGenerator on its own skips pools that already have fights and is
    # purely additive.
    #
    # In-action rather than a before_action because the category comes out of
    # the action's own params; hence the explicit return.
    def regenerate
      category = IndividualCategory.find(params.expect(:id))
      pool_number = Integer(params[:pool_number], exception: false)
      if pool_number.nil?
        redirect_to admin_individual_category_path(category), alert: t(".alert")
        return
      end
      # Only a redraw when there is something to destroy. The pool card's
      # button posts here for first-time generation too — it relabels itself
      # "Generate fights for this pool" while the pool has none — and that case
      # is additive, so R2a keeps it available on a frozen category, exactly as
      # the panel-level #generate is.
      return if category.pool_fights.exists?(pool_number: pool_number) && guard_frozen_pools!(category)
      category.transaction do
        category.pool_fights.where(pool_number: pool_number).destroy_all
        PoolFightGenerator.new(category, pool_number: pool_number).call
      end
      respond_with_pool(category, pool_number, notice: "Pool fights regenerated.")
    end

    private def kettei_sen_fighters_valid?(category, permitted)
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
