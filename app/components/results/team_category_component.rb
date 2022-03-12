# frozen_string_literal: true

module Results
  class TeamCategoryComponent < ViewComponent::Base
    def initialize(team_category:)
      @team_category = team_category
      @teams = team_category.teams.where.not(rank: nil).order(:rank, :name)
      @videos = team_category.videos.order(:name)
    end
  end
end
