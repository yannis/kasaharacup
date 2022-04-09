# frozen_string_literal: true

module Results
  class IndividualCategoryComponent < ViewComponent::Base
    def initialize(individual_category:)
      @individual_category = individual_category
      @ranked_participations = individual_category
        .participations
        .includes(:kenshi)
        .where.not(rank: nil)
        .order(:rank, "kenshis.last_name", "kenshis.first_name")
      @fighting_spirit_participations = individual_category
        .participations
        .includes(:kenshi)
        .where(fighting_spirit: true)
        .order(:rank, "kenshis.last_name", "kenshis.first_name")
      @videos = individual_category.videos.order(:name)
      @documents = individual_category.documents
    end
  end
end
