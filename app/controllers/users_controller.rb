# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @title = t(".title", full_name: @user.full_name)
  end
end
