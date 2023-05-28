# frozen_string_literal: true

class KenshisController < ApplicationController
  load_and_authorize_resource :cup, find_by: :year, class: "Cup"
  load_and_authorize_resource :kenshi, find_by: :id, class: "Kenshi", shallow: true, through: [:cup],
    param_method: :my_sanitizer, parent: false, except: [:new]

  before_action :set_variables, only: [:new, :edit, :update, :create]
  before_action :set_personal_info, only: %w[edit]
  before_action :check_deadline, only: [:new, :edit, :update, :create, :destroy]
  before_action :prevent_page_caching, only: [:new, :create, :edit, :update]
  respond_to :html

  def index
    @current_cup = @cup.presence || @current_cup
    @title = t(".title")
    if params[:category] && %w[team open ladies juniors].include?(params[:category])
      category = params[:category]
      @kenshis = @kenshis.category(category) if category
      @title = t("kenshis.index.title_#{category}")
    end
    @kenshis = @kenshis
      .includes(:user, :club, participations: [:category])
      .order(created_at: :desc)
    respond_with @kenshis do |format|
      format.html
      format.csv {
        filename = Time.zone.now.to_fs(:datetime).gsub(/[^0-9a-z]/,
          "") + "_" + @title.gsub(/[^0-9a-zA-Z]/, "_").gsub("__", "_") + ".csv"
        send_data(
          Kenshi.to_csv(@kenshis),
          as: "text/csv; charset=utf-8; header=present",
          filename: filename
        )
      }
    end
  end

  def show
    @current_cup = @cup.presence || @current_cup
    @title = "Kenshi “#{@kenshi.full_name}”"
    respond_with @kenshi
  end

  def new
    authorize! :create, Kenshi
    authorize! :register, @cup
    @current_cup = @cup.presence || @current_cup
    if params[:self] == "true"
      existing_kenshis = current_user.kenshis.where(first_name: current_user
        .first_name, last_name: current_user.last_name, cup: @current_cup)
      if existing_kenshis.present?
        redirect_to cup_kenshi_path(@current_cup, existing_kenshis.first, locale: I18n.locale),
          notice: t("kenshis.self.exist")
        return
      else
        @kenshi = Kenshi.from(current_user)
        @title = t(".yourself")
      end
    elsif params[:id]
      origin_kenshi = Kenshi.find(params[:id])
      @kenshi = origin_kenshi.dup
      @kenshi.first_name = @kenshi.last_name = @kenshi.email = @kenshi.dob = nil
      @title = t(".duplicate", full_name: origin_kenshi.full_name)
      origin_kenshi.participations.each do |participation|
        @kenshi.participations << Participation.new(category: participation.category, team: participation.team,
          ronin: participation.ronin)
      end
    else
      @kenshi = Kenshi.new(email: current_user.email, club: current_user.club)
      @title = t(".title")
    end
    set_personal_info
    respond_with @kenshi
  end

  def edit
    @title = t(".title", full_name: @kenshi.full_name)
    respond_with @kenshi
  end

  def create
    authorize! :register, @cup
    if Time.current > @cup.deadline
      redirect_back_or_default user_path, notice: "Deadline is passed"
      return
    end
    @kenshi.cup = @cup
    if @kenshi.save
      notice = t("kenshis.create.flash.notice")
      redirect_to cup_user_path(@cup, locale: I18n.locale), notice: notice
    else
      if params[:self] == "true"
        existing_kenshis = current_user.kenshis.where(first_name: current_user
          .first_name, last_name: current_user.last_name)
        if existing_kenshis.present?
          redirect_to(cup_kenshi_path(@cup, existing_kenshis.first, locale: I18n.locale),
            notice: t("kenshis.self.exist"), status: :unprocessable_entity)
        else
          @kenshi = Kenshi.from(current_user)
          @title = t("kenshis.new.yourself")
        end
      elsif params[:id]
        origin_kenshi = Kenshi.find(params[:id])
        @kenshi = origin_kenshi.dup
        @kenshi.first_name = @kenshi.last_name = @kenshi.email = @kenshi.dob = nil
        @title = t("kenshis.new.duplicate", full_name: origin_kenshi.full_name)
        origin_kenshi.participations.each do |participation|
          @kenshi.participations << Participation.new(category: participation.category, team: participation.team,
            ronin: participation.ronin)
        end
      else
        @kenshi.club = current_user.club
        @title = t("kenshis.new.title")
      end
      respond_with @kenshi do |format|
        flash.now[:alert] = "Kenshi not registered"
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @kenshi.update(my_sanitizer)
      notice = t("kenshis.update.flash.notice")
      redirect_to cup_user_path(@current_cup, locale: I18n.locale), notice: notice
    else
      @title = t("kenshis.edit.title", full_name: @kenshi.full_name)
      @kenshi.valid?
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @kenshi.destroy
    flash[:notice] = t(".notice")
    redirect_to cup_user_path(@current_cup, locale: I18n.locale)
  rescue => e
    redirect_to cup_kenshi_path(@current_cup, @kenshi, locale: I18n.locale), alert: e.message
  end

  private def set_variables
    @teams = @cup.teams.incomplete.order(:name) + @current_cup.teams.complete.order(:name)
    @club_names = Club.order(:name).pluck(:name).map { |club| club.strip }.uniq
    @products = @cup.products.where(display: true).order(:position)
  end

  private def set_personal_info
    @kenshi.build_personal_info unless @kenshi.personal_info
  end

  private def my_sanitizer
    params[:kenshi][:participations_attributes]&.reject! { |k, v|
      v["category_type"] == "IndividualCategory" && v["category_id"].blank?
    }
    params.require(:kenshi).permit(
      :first_name, :last_name, :email, :dob, :female, :club_id, :club_name, :grade, :club_name,
      purchases_attributes: [:id, :product_id, :_destroy],
      individual_category_ids: [],
      participations_attributes: [:id, :category_type, :category_id, :ronin, :team_name, :_destroy],
      product_ids: [],
      personal_info_attributes: %i[
        residential_address
        residential_zip_code
        residential_city
        residential_country
        residential_phone_number
        origin_country
        document_type
        document_number
      ]
    )
  end
end
