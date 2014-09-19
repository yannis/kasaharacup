require 'acts_as_fighter'
class Participation < ActiveRecord::Base
  acts_as_fighter
  attr_accessor :category_individual, :category_team
  belongs_to :category, polymorphic: true, autosave: true
  belongs_to :kenshi, inverse_of: :participations
  belongs_to :team

  before_validation :assign_category

  validates :kenshi, presence: true
  validates :category, presence: true

  validates_presence_of :pool_position, if: lambda{|p| p.pool_number.present?}
  validates_uniqueness_of :kenshi_id, scope: [:category_type, :category_id], if: lambda{|p| p.ronin.blank?}, allow_nil: true
  validates_numericality_of :pool_number, only_integer: true, greater_than: 0, allow_nil: true

  validates_each :category do |record, attr, value|
    kenshi = record.kenshi
    category = record.category

    # if kenshi && category
    age = kenshi.age_at_cup

    if category.min_age && age < category.min_age
      record.errors.add(attr, :too_young, name: category.name)
    end
    if category.max_age && age > category.max_age
      record.errors.add(attr, :too_old, name: category.name)
    end
  end

  delegate :full_name, to: 'kenshi', allow_nil: true
  delegate :grade, to: 'kenshi', allow_nil: true
  delegate :club, to: 'kenshi', allow_nil: true

  def self.no_pool
    self.where(pool_number: nil)
  end

  def self.to(category)
    self.where(category: category)
  end

  def self.ronins
    self.where(ronin: true)
  end

  def category_individual
    self.category.id if self.category.is_a?(IndividualCategory)
  end

  def category_team
    self.category.id if self.category.is_a?(TeamCategory)
  end

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

  # def full_name
  #   full_name = [category.name]
  #   full_name << "(#{team.name})" if team
  #   full_name.join(" ")
  # end

  protected

  def assign_category
    if @category_individual.present? && @category_team.present?
      errors.add(:category, "can't have both an individual and a team category")
    end
    if @category_individual.present?
      self.category = IndividualCategory.find(@category_individual)
    end
    if @category_team.present?
      self.category = TeamCategory.find(@category_team)
    end
  end
end
