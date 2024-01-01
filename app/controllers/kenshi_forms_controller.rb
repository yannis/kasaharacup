# frozen_string_literal: true

class KenshiFormsController < ApplicationController
  load_and_authorize_resource :cup, find_by: :year, class: "Cup"

  before_action :set_variables, only: [:new, :edit, :update, :create]
  before_action :check_deadline, only: [:new, :edit, :update, :create]
  before_action :prevent_page_caching, only: [:new, :create, :edit, :update]
  respond_to :html

  def new
    authorize! :register, @cup
    authorize! :create, Kenshi
    @kenshi_form = KenshiForm.new(cup: @cup, user: current_user, kenshi: Kenshi.new)
  end

  def edit
    @kenshi = @cup.kenshis.find(params[:id])
    authorize! :update, @kenshi
    @kenshi_form = KenshiForm.new(cup: @cup, user: current_user, kenshi: @kenshi)
  end

  def create
    authorize! :register, @cup
    @kenshi_form = KenshiForm.new(cup: @cup, user: current_user, kenshi: @kenshi)
    if @kenshi_form.save(my_sanitizer)
      redirect_to cup_user_path(@cup), notice: notice
    else
      set_variables
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize! :register, @cup
    @kenshi = @cup.kenshis.find(params[:id])
    authorize! :update, @kenshi
    @kenshi_form = KenshiForm.new(cup: @cup, user: current_user, kenshi: @kenshi)
    if @kenshi_form.save(my_sanitizer)
      redirect_to cup_user_path(@cup), notice: notice
    else
      set_variables
      render :edit, status: :unprocessable_entity
    end
  end

  private def set_variables
    @team_categories = @cup.team_categories.order(:name)
    @individual_categories = @cup.individual_categories.order(:name)
    @teams = @cup.teams.incomplete.order(:name) + @current_cup.teams.complete.order(:name)
    @club_names = Club.order(:name).pluck(:name).map { |club| club.strip }.uniq
    @products = @cup.products.where(display: true).order(:position)
  end

  private def my_sanitizer
    params.require(:kenshi_form).permit(
      kenshi: %i[first_name last_name email dob female club_id club_name grade club_name],
      purchases: {},
      participations: {},
      personal_info: %i[
        email residential_address residential_zip_code residential_city residential_country
        residential_phone_number origin_country document_type document_number
      ]
    )
  end
end
