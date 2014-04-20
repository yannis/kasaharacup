require "acts_as_category"
class TeamCategory < ActiveRecord::Base

  acts_as_category

  belongs_to :cup, inverse_of: :team_categories
  has_many :teams, inverse_of: :team_category, dependent: :destroy
  has_many :participations, as: :category, dependent: :destroy
  has_many :kenshis, through: :teams
end
