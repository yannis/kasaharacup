# frozen_string_literal: true

# Transient grouping of a team category's teams that share a pool_number,
# ordered by pool_position (the sibling of Pool for individual categories).
class TeamPool
  attr_reader :number, :teams

  def initialize(number:, teams:)
    @number = number
    @teams = teams.sort_by { |team| team.pool_position || Float::INFINITY }
  end
end
