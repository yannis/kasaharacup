require "acts_as_category"
class IndividualCategory < ActiveRecord::Base

  acts_as_category

  belongs_to :cup, inverse_of: :individual_categories
  has_many :participations, as: :category, dependent: :destroy
  has_many :kenshis, through: :participations
end
