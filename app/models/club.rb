# frozen_string_literal: true

class Club < ApplicationRecord
  has_many :users
  has_many :kenshis

  validates :name, presence: true
  validates :name, uniqueness: true

  def to_s
    name
  end
end
