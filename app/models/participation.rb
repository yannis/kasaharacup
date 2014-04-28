require 'acts_as_fighter'
class Participation < ActiveRecord::Base
  acts_as_fighter
  belongs_to :category, inverse_of: :participations, polymorphic: true, autosave: true
  belongs_to :kenshi, inverse_of: :participations
  belongs_to :team

  validates_presence_of :category_id
  # validates_presence_of :kenshi_id
  validates_presence_of :pool_position, if: lambda{|p| p.pool_number.present?}
  validates_uniqueness_of :category_id, scope: :kenshi_id, if: lambda{|p| p.ronin.blank?}

  # def self.set_for_user(user, attributes)
  #   id = attributes.fetch :id, nil
  #   category_type = attributes.fetch :category_type
  #   category_id = attributes.fetch :category_id
  #   participation_id = attributes.fetch :id, nil
  #   team_name = attributes.fetch :team_name, nil
  #   ronin = attributes.fetch :ronin, nil

  #   current_participation = self.find(id) if id.present?

  #   if category_type == "TeamCategory"
  #     category = TeamCategory.find category_id
  #     params = {team_name: team_name, ronin: ronin}
  #     if participation.present?
  #       participation.update_attributes params
  #     else
  #       self.participations.new params.merge! category: category
  #     end
  #   elsif category_type == "IndividualCategory"
  #     category = IndividualCategory.find category_id
  #     if participation
  #       participation.destroy unless participate
  #     else
  #       self.participations.new category: category
  #     end
  #   end

  #   category
  # end

  def team_name=(team_name)
    if self.category.is_a? TeamCategory
      if team_name.blank? && self.ronin.blank?
        self.mark_for_destruction
      end
      if team_name.present?
        # self.team_id = nil
        self.ronin = nil
        self.team = Team.find_or_initialize_by team_category: self.category, name: team_name
      elsif team_name.blank? || ronin.present?
        self.team = nil
      end
    end
  end

end
