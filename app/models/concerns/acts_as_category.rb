# frozen_string_literal: true

require "translate"

module ActsAsCategory
  extend ActiveSupport::Concern

  # Both category types freeze the same way; only "is there anything to freeze"
  # differs, and each class answers that itself.
  include Freezable

  included do
    has_many :fights, dependent: :destroy

    enum :gender_restriction, {female: "female", male: "male"}

    validates :name, presence: true
    validates :cup_id, presence: true
    validates :name, uniqueness: {scope: :cup_id}
    validate :pool_settings_not_frozen

    translate :description

    # NOT memoized: regeneration paths (PoolMembershipMove -> PoolFightGenerator)
    # reuse one category instance and re-read this after mutating pool
    # membership, so a cached snapshot would regenerate from stale membership.
    def pools
      pools = []
      if pool_size.to_i > 1
        grouped_participations = participations.includes(kenshi: [:cup,
          :club]).where.not(participations: {pool_number: nil}).group_by { |p|
          p.pool_number
        }
        # sort: the participations come back unordered, so group_by would
        # otherwise yield the pools in row order rather than by pool number.
        grouped_participations.sort.each do |i, participations|
          pools << Pool.new(participations: participations, number: i)
        end
      end
      pools
    end

    def set_smart_pools
      SmartPooler.new(self).set_pools
    end

    def data
      {
        fights: fights.where(pool_number: nil).bracket_order.to_a
      }
    end

    # R7. These decide what a redraw produces and what the bracket reads off
    # the pools, so they belong to the formation the pools freeze protects:
    # changing one under a frozen draw leaves the stored pools and the settings
    # describing different competitions.
    #
    # team_size exists only on TeamCategory; changed_attribute_names_to_save
    # lists real attributes, so naming it here is a no-op on the other side.
    private def pool_settings_not_frozen
      return unless pools_frozen?

      changed = %w[pool_size out_of_pool team_size] & changed_attribute_names_to_save
      changed.each { |attribute| errors.add(attribute, :pools_frozen) }
    end
  end
end
