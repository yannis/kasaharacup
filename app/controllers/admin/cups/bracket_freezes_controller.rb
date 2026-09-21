# frozen_string_literal: true

module Admin
  module Cups
    # Freezes (POST) or unfreezes (DELETE) the bracket of every category of one
    # cup. Cup-level twin of
    # Admin::IndividualCategories::BracketFreezesController.
    class BracketFreezesController < Admin::BaseController
      include Admin::Cups::FreezeAll

      def create = apply_to_all(freeze: true)

      def destroy = apply_to_all(freeze: false)

      private def flag = :bracket
    end
  end
end
