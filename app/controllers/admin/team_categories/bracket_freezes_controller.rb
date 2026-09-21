# frozen_string_literal: true

module Admin
  module TeamCategories
    # Freezes (POST) and unfreezes (DELETE) a team category's bracket.
    # Team twin of Admin::IndividualCategories::BracketFreezesController.
    class BracketFreezesController < Admin::BaseController
      include Admin::Freezing
      include Admin::TeamCategories::FreezeStreams

      def create = apply(freeze: true)

      def destroy = apply(freeze: false)

      private def flag = :bracket
    end
  end
end
