# frozen_string_literal: true

require "translate"

class Headline < ApplicationRecord
  belongs_to :cup

  validates :title_fr, presence: true
  validates :title_en, presence: true
  validates :content_fr, presence: true
  validates :content_en, presence: true

  translate :title, :content

  def self.shown
    where(shown: true)
  end

  def to_param
    "#{id}-#{title.parameterize}"
  end
end
