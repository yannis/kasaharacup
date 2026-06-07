# frozen_string_literal: true

class TeamPoolComponent < ViewComponent::Base
  include ActionView::RecordIdentifier

  def initialize(team_category:, pool_number:, pool: nil, admin: true)
    @team_category = team_category
    @pool_number = pool_number
    @pool = pool
    @admin = admin
  end

  private attr_reader :team_category, :pool_number, :admin

  private def pool
    @pool ||= team_category.team_pools.find { |p| p.number == pool_number }
  end

  private def teams
    @teams ||= pool&.teams || []
  end

  private def encounters
    @encounters ||= team_category.encounters_by_pool_number.fetch(pool_number, [])
  end

  private def standings_rows
    @standings_rows ||= TeamPoolStandings.for(teams: teams, encounters: encounters)
  end

  private def dom_id_for_pool
    "team_pool_#{team_category.id}_#{pool_number}"
  end
end
