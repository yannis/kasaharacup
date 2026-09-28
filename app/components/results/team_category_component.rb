# frozen_string_literal: true

module Results
  class TeamCategoryComponent < ViewComponent::Base
    def initialize(team_category:)
      @team_category = team_category
      @teams = team_category.teams.where.not(rank: nil).order(:rank, :name).to_a
      @videos = team_category.videos.order(:name).to_a
      @documents = team_category.documents.to_a
      @bracket = team_category.bracket_encounters.exists?
    end

    # A category with no bracket, ranking or attachment yet would be an empty card.
    def render? = bracket? || list?

    private def bracket? = @bracket

    private def list? = @teams.any? || attachments?

    private def attachments? = @videos.any? || @documents.any?
  end
end
