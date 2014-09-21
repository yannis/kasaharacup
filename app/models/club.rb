class Club < ActiveRecord::Base
  has_many :users
  has_many :kenshis

  validates_presence_of :name
  validates_uniqueness_of :name

  def to_s
    name
  end
end
