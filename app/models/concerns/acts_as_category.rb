# frozen_string_literal: true

require "translate"
require "smart_pooler"

module ActsAsCategory
  extend ActiveSupport::Concern

  included do
    has_many :fights, dependent: :destroy

    validates :name, presence: true
    validates :cup_id, presence: true
    validates :name, uniqueness: {scope: :cup_id}

    translate :description

    def pools
      pools = []
      if pool_size > 1
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

    def set_smart_pools
      SmartPooler.new(self).set_pools
    end

    def tree
      Tree.new(self)
    end

    def data
      {
        tree: {
          elements: tree.elements,
          depth: tree.depth,
          branch_number: tree.branch_number
        }
      }
    end
  end
end
