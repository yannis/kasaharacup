class Cup < ActiveRecord::Base
  has_many :kenshis, inverse_of: :cup, dependent: :destroy
  has_many :individual_categories, inverse_of: :cup, dependent: :destroy
  has_many :team_categories, inverse_of: :cup, dependent: :destroy
  has_many :events, inverse_of: :cup, dependent: :destroy

  validates_presence_of :start_on
  validates_presence_of :deadline
  validates_uniqueness_of :start_on

  before_validation :set_deadline

  def to_param
    year
  end

  def year
    start_on.year
  end

  private

    def set_deadline
      self.deadline = (self.start_on.to_time-7.days) if self.start_on.present? && self.deadline.blank?
    end
end
