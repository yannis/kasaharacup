require 'acts_as_fighter'
class Participation < ActiveRecord::Base
  acts_as_fighter
  belongs_to :category, inverse_of: :participations, polymorphic: true
  belongs_to :kenshi, inverse_of: :participations
  belongs_to :team

  validates_presence_of :category_id
  # validates_presence_of :kenshi_id
  validates_presence_of :pool_position, if: lambda{|p| p.pool_number.present?}
  validates_uniqueness_of :category_id, scope: :kenshi_id, if: lambda{|p| p.ronin.blank?}

  # before_validate

  def team_name=(team_name)
    if team_name.present?
      self.team_id = nil
      self.ronin = nil
      self.team = Team.new team_category: self.category, name: team_name
    end
  end
end
