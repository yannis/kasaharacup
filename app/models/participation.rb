require 'acts_as_fighter'
class Participation < ActiveRecord::Base
  acts_as_fighter
  belongs_to :category, inverse_of: :participations, polymorphic: true
  belongs_to :kenshi, inverse_of: :participations
  belongs_to :team

  validates_presence_of :category_id
  # validates_presence_of :kenshi_id
  validates_presence_of :pool_position, if: lambda{|p| p.pool_number.present?}

  def new_team_name=(new_team_name)
    if new_team_name.present?
      self.team_id = nil
      self.ronin = nil
      self.team = Team.new team_category: self.category, name: new_team_name
    end
  end
end
