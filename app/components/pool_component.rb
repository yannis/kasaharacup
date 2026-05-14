# frozen_string_literal: true

class PoolComponent < ViewComponent::Base
  include ActionView::RecordIdentifier

  def initialize(category:, pool_number:, admin: true)
    @category = category
    @pool_number = pool_number
    @admin = admin
  end

  private attr_reader :category, :pool_number, :admin

  private def pool
    @pool ||= category.pools.find { |p| p.number == pool_number }
  end

  private def participations
    @participations ||= pool&.participations || []
  end

  private def pool_fights
    @pool_fights ||= category.pool_fights
      .where(pool_number: pool_number)
      .includes(:fighter_1, :fighter_2, :winner, :fight_points)
      .to_a
  end

  private def cyclic_fights
    pool_fights.reject(&:tiebreaker).sort_by(&:number)
  end

  private def tiebreaker_fights
    pool_fights.select(&:tiebreaker).sort_by { |f| [f.created_at.to_f, f.id] }
  end

  private def standings_rows
    PoolStandings.for(participations: participations, fights: pool_fights)
  end

  private def dom_id_for_pool
    helpers.pool_dom_id(category, pool_number)
  end

  private def point_codes
    FightPoint::CODES
  end
end
