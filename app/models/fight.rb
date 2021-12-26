# frozen_string_literal: true

class Fight < ApplicationRecord
  belongs_to :individual_category
  belongs_to :winner, polymorphic: true, foreign_type: "fighter_type", optional: true
  belongs_to :parent_fight_1, class_name: "Fight", optional: true
  belongs_to :parent_fight_2, class_name: "Fight", optional: true
  belongs_to :fighter_1, polymorphic: true, foreign_type: "fighter_type"
  belongs_to :fighter_2, polymorphic: true, foreign_type: "fighter_type"

  validates :number, presence: true
  validates :number, uniqueness: {scope: :individual_category_id}
end
