# frozen_string_literal: true

module ActsAsFighter
  extend ActiveSupport::Concern

  included do
    has_many :fights

    def win_fight(fight)
      fight.update winner: self
    end
  end
end
