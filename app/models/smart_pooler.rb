# frozen_string_literal: true

class SmartPooler
  attr_reader :category, :participants, :poules, :pool_size

  def initialize(category)
    @category = category
    @pool_size = category.pool_size
    @participants = category.participations.to_a
    @poules = []
  end

  def set_pools
    poule = Pool.new
    while participants.size > 0
      participants.shuffle!
      selected_participants = participants
      if poule.contains_high_rank?
        selected_participants = selected_participants.select { |p| p.kenshi.grade.to_i < 3 }
      end
      already_selected_clubs = poule.participations.map { |p| p.kenshi.club }
      selected_participants = selected_participants.select { |p| already_selected_clubs.exclude?(p.kenshi.club) }
      p = if selected_participants.empty?
        participants.first
      else
        selected_participants.first
      end
      poule.participations << participants.delete(p)
      if poule.participations.size == pool_size || participants.empty?
        poules << poule
        poule = Pool.new
      end
      set_participations
    end
  end

  protected
    def set_participations
      Participation.transaction do
        poules.each_with_index do |poule, i|
          poule.participations.each_with_index do |participation, j|
            participation.update(pool_number: i + 1, pool_position: j + 1)
          end
        rescue StandardError? => e
          Rails.logger.debug e
        end
      end
    end
end
