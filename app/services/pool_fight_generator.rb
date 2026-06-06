# frozen_string_literal: true

class PoolFightGenerator
  def initialize(category, pool_number: nil)
    @category = category
    @pool_number = pool_number
  end

  def call
    category.transaction do
      pools_to_generate.each { |pool| generate_for(pool) }
    end
  end

  private attr_reader :category, :pool_number

  private def pools_to_generate
    candidates = category.pools.sort_by(&:number)
    candidates = candidates.select { |pool| pool.number == pool_number } if pool_number
    candidates.reject do |pool|
      category.pool_fights.exists?(pool_number: pool.number)
    end
  end

  private def generate_for(pool)
    participations = pool.participations
    pairs = Pools::CyclicPairing.pairs_for(participations.size)
    pairs.each_with_index do |(low, high), index|
      participation_1 = participations[low - 1]
      participation_2 = participations[high - 1]
      next if participation_1.blank? || participation_2.blank?

      category.fights.create!(
        pool_number: pool.number,
        number: index + 1,
        fighter_type: "Kenshi",
        fighter_1_id: participation_1.kenshi_id,
        fighter_2_id: participation_2.kenshi_id
      )
    end
  end
end
