# frozen_string_literal: true

module Admin
  module IndividualCategories
    # Freezes (POST) and unfreezes (DELETE) an individual category's pool
    # formation. Twin of BracketFreezesController, and they share their stream
    # set through Admin::IndividualCategories::FreezeStreams: on this side the
    # seeds panel, the pool cards and the tree all subscribe to one stream and
    # both flags change how all three render, so there is nothing to split.
    class PoolFreezesController < Admin::BaseController
      include Admin::Freezing
      include Admin::IndividualCategories::FreezeStreams

      def create = apply(freeze: true)

      def destroy = apply(freeze: false)

      private def flag = :pools
    end
  end
end
