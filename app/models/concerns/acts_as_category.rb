# frozen_string_literal: true

require "translate"

module ActsAsCategory
  extend ActiveSupport::Concern

  included do
    has_many :fights, dependent: :destroy

    enum :gender_restriction, {female: "female", male: "male"}

    validates :name, presence: true
    validates :cup_id, presence: true
    validates :name, uniqueness: {scope: :cup_id}

    translate :description

    # Memoized for the request: a show page renders one PoolComponent per pool,
    # and each looks up its pool here — without memoization that re-runs the
    # participations query once per pool.
    def pools
      @pools ||= begin
        pools = []
        if pool_size.to_i > 1
          grouped_participations = participations.includes(kenshi: [:cup,
            :club]).where.not(participations: {pool_number: nil}).group_by { |p|
            p.pool_number
          }
          grouped_participations.each do |i, participations|
            pools << Pool.new(participations: participations, number: i)
          end
        end
        pools
      end
    end

    def set_smart_pools
      SmartPooler.new(self).set_pools
    end

    def data
      {
        fights: fights.where(pool_number: nil).bracket_order.to_a
      }
    end
  end
end
