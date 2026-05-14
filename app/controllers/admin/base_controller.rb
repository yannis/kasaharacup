# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    before_action :authenticate_admin_user!

    private def respond_with_tree(category, notice: nil)
      respond_to do |format|
        format.html { redirect_to admin_individual_category_path(category), notice: notice }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(category, :competition_tree),
            CompetitionTreeComponent.new(category: category, admin: true),
            method: :morph
          )
        end
      end
    end
  end
end
