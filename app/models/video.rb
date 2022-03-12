# frozen_string_literal: true

class Video < ApplicationRecord
  belongs_to :category, polymorphic: true

  validates :name, presence: true, uniqueness: {scope: [:category_type, :category_id]}
  validates :url, presence: true, uniqueness: true
end
