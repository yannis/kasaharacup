require "translate"
class Headline < ActiveRecord::Base
  belongs_to :cup

  validates_presence_of :title_fr
  validates_presence_of :title_en
  validates_presence_of :content_fr
  validates_presence_of :content_en
  validates_presence_of :cup_id

  translate :title, :content

  def self.shown
    where(shown: true)
  end
end
