class Pool

  attr_accessor :participations, :number

  def initialize(data={})
    @number = data.fetch(:number, nil)
    @participations = [data.fetch(:participations, nil)].flatten.uniq.compact
  end

  def contains_high_rank?
    participations.select{|p| p.kenshi.grade.to_i > 3 }.present?
  end

  def contains_club?(club)
    participations.select{|p| p.kenshi.club == club }.present?
  end

  def to_csv
    data = [number]
    for participation in participations
      data << "#{participation.kenshi.full_name} (#{participation.kenshi.club})"
    end
    return data
  end
end
