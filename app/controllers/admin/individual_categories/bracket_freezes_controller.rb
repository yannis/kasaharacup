# frozen_string_literal: true

module Admin
  module IndividualCategories
    # Freezes (POST) and unfreezes (DELETE) an individual category's bracket.
    # Twin of PoolFreezesController — see there for why the two share one
    # stream set.
    class BracketFreezesController < Admin::BaseController
      include Admin::Freezing
      include Admin::IndividualCategories::FreezeStreams

      def create = apply(freeze: true)

      def destroy = apply(freeze: false)

      private def flag = :bracket
    end
  end
end
