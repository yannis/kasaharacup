class Fight < ActiveRecord::Base
  belongs_to :individual_category
  belongs_to :winner, polymorphic: true, foreign_type: "fighter_type"
  belongs_to :parent_fight_1
  belongs_to :parent_fight_2
  belongs_to :fighter_1, polymorphic: true, foreign_type: "fighter_type"
  belongs_to :fighter_2, polymorphic: true, foreign_type: "fighter_type"

  validates_presence_of :number
  validates_uniqueness_of :number, scope: :individual_category_id
end
