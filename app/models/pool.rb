# frozen_string_literal: true

class Pool
  attr_accessor :participations, :number

  def initialize(data = {})
    @number = data.fetch(:number, nil)
    @participations = [data.fetch(:participations, nil)].flatten.uniq.compact.sort_by(&:pool_position)
  end

  def contains_high_rank?
    participations.select { |p| p.kenshi.grade.to_i > 3 }.present?
  end

  def contains_club?(club)
    participations.select { |p| p.kenshi.club == club }.present?
  end

  def to_csv
    data = [number]
    participations.each do |participations|
      data << "#{participation.kenshi.full_name} (#{participation.kenshi.club})"
    end
    data
  end
end
