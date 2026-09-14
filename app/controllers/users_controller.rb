# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @title = t(".title", full_name: @user.full_name)
    # Loaded here, not left as a relation: the view asks `any?` before rendering,
    # which on an unloaded relation costs a SELECT 1 … LIMIT 1 of its own.
    @kenshis = @user.kenshis.for_cup(@current_cup)
      .includes(:user, :club, {participations: [:category, :team]}, {purchases: :product})
      .to_a
  end
end
