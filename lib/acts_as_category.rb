require "translate"
require "smart_pooler"
module ActsAsCategory

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def acts_as_category
      include InstanceMethods

      # has_many :participations, inverse_of: :category, dependent: :destroy
      # has_many :kenshis, through: :participations
      has_many :fights, dependent: :destroy

      validates_presence_of :name
      validates_presence_of :cup_id
      validates_uniqueness_of :name, scope: :cup_id

      translate :description
    end

    # def booking_callback(request)
    #   BookingCallback.new(request, self)
    # end
  end

  module InstanceMethods

    def pools
      pools = []
      if pool_size > 1
        grouped_participations = self.participations.where("participations.pool_number IS NOT NULL").group_by{|p| p.pool_number}
        grouped_participations.each do |i, participations|
          pools << Pool.new(participations: participations, number: i)
        end
      end
      return pools
    end

    def set_smart_pools
      SmartPooler.new(self).set_pools
    end

    # def set_pools(poules)
    #   Participation.transaction do
    #     poules.each_with_index do |poule, i|
    #       begin
    #         for participation in poule.participations
    #           participation.update_attributes(pool_number: i+1)
    #         end
    #       rescue Exception => e
    #         p e
    #       end
    #     end
    #   end
    #   return self.pools
    # end

    def tree
      Tree.new(self)
    end

    def data
      {
        tree: {
          elements: self.tree.elements,
          depth: self.tree.depth,
          branch_number: self.tree.branch_number
        }
      }
    end
  end
end

ActiveRecord::Base.send(:include, ActsAsCategory)
