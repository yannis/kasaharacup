# frozen_string_literal: true

module Admin
  module TeamCategories
    # Freezes (POST) and unfreezes (DELETE) a team category's pool formation.
    # Team twin of Admin::IndividualCategories::PoolFreezesController; the
    # stream split that makes this side different lives in FreezeStreams.
    class PoolFreezesController < Admin::BaseController
      include Admin::Freezing
      include Admin::TeamCategories::FreezeStreams

      def create = apply(freeze: true)

      def destroy = apply(freeze: false)

      private def flag = :pools
    end
  end
end
