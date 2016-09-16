class KenshisController < ApplicationController

  prepend_before_filter :set_user

  # load_and_authorize_resource :user
  load_and_authorize_resource :cup, find_by: :year, class: "Kendocup::Cup"
  load_and_authorize_resource :kenshi, find_by: :id, class: "Kendocup::Kenshi", shallow: true, through: [:cup, :user], param_method: :my_sanitizer, parent: false, except: [:new]

  before_filter :set_variables, only: [:new, :edit, :update, :create]
  before_filter :set_user
  before_filter :check_deadline, only: [:new, :edit, :update, :create, :destroy]
  respond_to :html

  # autocomplete :kenshi, :club, scopes: [:unique_by_club], full_model: true

  def index
    @current_cup = @cup.presence || @current_cup
    if @user && !user_signed_in?
      redirect_to cup_kenshis_path(@current_cup) and return
    end
    if @user && can?(:read, @user)
      @title =  t('kenshis.index.title_for_user', user_full_name: @user.full_name)
    else
      @title =  t('kenshis.index.title')
    end
    if params[:category] and %w{team open ladies juniors}.include? params[:category]
      category = params[:category]
      @kenshis = @kenshis.category(category) if category
      @title =  t("kenshis.index.title_#{category}")
    end
    @kenshis = @kenshis.includes(:user)
    respond_with @kenshis do |format|
      format.html
      format.csv {
        filename = Time.now.to_s(:datetime).gsub(/[^0-9a-z]/, '')+'_'+@title.gsub(/[^0-9a-zA-Z]/, "_").gsub('__', "_") + ".csv"
        send_data(
          Kendocup::Kenshi.to_csv(@kenshis),
          as: 'text/csv; charset=utf-8; header=present',
          filename: filename
        )
      }
    end
  end

  def show
    @current_cup = @cup.presence || @current_cup
    if @user && !user_signed_in?
      redirect_to cup_kenshi_path(@current_cup, params[:id])
      return
    end
    @title = "Kenshi “#{@kenshi.full_name}”"
    respond_with @kenshi
  end

  def new
    authorize! :create, Kendocup::Kenshi
    @current_cup = @cup.presence || @current_cup
    if @user.blank? || (@user != current_user && !current_user.admin?)
      redirect_to new_cup_user_kenshi_path(@current_cup, current_user, locale: I18n.locale)
      return
    end
    if @user == current_user && params[:self] == 'true'
      existing_kenshis = current_user.kenshis.where(first_name: current_user.
        first_name, last_name: current_user.last_name, cup: @current_cup)
      if existing_kenshis.present?
        redirect_to cup_kenshi_path(@current_cup, existing_kenshis.first, locale: I18n.locale), notice: t("kenshis.self.exist")
        return
      else
        @kenshi = Kendocup::Kenshi.from(current_user)
        @title = t('kenshis.new.yourself')
      end
    elsif params[:id]
      origin_kenshi = Kendocup::Kenshi.find(params[:id])
      @kenshi = origin_kenshi.dup
      @kenshi.first_name = @kenshi.last_name = @kenshi.email = @kenshi.dob = nil
      @title = t("kenshis.new.duplicate", full_name: origin_kenshi.full_name)
      origin_kenshi.participations.each do |participation|
        @kenshi.participations << Kendocup::Participation.new(category: participation.category, team: participation.team, ronin: participation.ronin)
      end
    else
      @kenshi = Kendocup::Kenshi.from(current_user)
      @kenshi.club = @user.club if @user.present?
      @title = t('kenshis.new.title')
    end
    @kenshi.female = false if @kenshi.female.nil?
    # @cup.team_categories.each do |cat|
    #   @kenshi.participations.build category: cat
    # end
    # @cup.individual_categories.each do |cat|
    #   @kenshi.participations.build category: cat
    # end
    # @participations_to_teams = @kenshi.participations.select{|p| p.category.is_a? TeamCategory}
    # @participations_to_ind = @kenshi.participations.select{|p| p.category.is_a? IndividualCategory}
    respond_with @kenshi
  end

  def edit
    @title = t('kenshis.edit.title', full_name: @kenshi.full_name)
    respond_with @kenshi
  end

  def create
    if Time.current > @cup.deadline
      redirect_back_or_default root_path(@user, locale: I18n.locale) , notice: 'Deadline is passed'
      return
    end
    @kenshi.cup = @cup
    if @kenshi.save
      respond_with @kenshi do |format|
        notice = t('kenshis.create.flash.notice')
        format.html { redirect_to cup_user_path(@cup, @kenshi.user, locale: I18n.locale), notice: notice }
        format.js {
          @origin = params[:origin]
          flash.now[:notice] = notice
          render '/layouts/create_and_insert_in_select', layout: false
        }
      end
    else

      if @user.blank? || (@user != current_user && !current_user.admin?)
        redirect_to new_cup_user_kenshi_path(@cup, current_user, locale: I18n.locale)
        return
      end
      if @user == current_user && params[:self] == 'true'
        existing_kenshis = current_user.kenshis.where(first_name: current_user.
          first_name, last_name: current_user.last_name)
        if existing_kenshis.present?
          redirect_to cup_kenshi_path(@cup, existing_kenshis.first, locale: I18n.locale), notice: t("kenshis.self.exist")
          return
        else
          @kenshi = Kendocup::Kenshi.from(current_user)
          @title = t('kenshis.new.yourself')
        end
      elsif params[:id]
        origin_kenshi = Kendocup::Kenshi.find(params[:id])
        @kenshi = origin_kenshi.dup
        @kenshi.first_name = @kenshi.last_name = @kenshi.email = @kenshi.dob = nil
        @title = t("kenshis.new.duplicate", full_name: origin_kenshi.full_name)
        origin_kenshi.participations.each do |participation|
          @kenshi.participations << Participation.new(category: participation.category, team: participation.team, ronin: participation.ronin)
        end
      else
        @kenshi.club = @user.club if @user.present?
        @title = t('kenshis.new.title')
      end
      @kenshi.female = false if @kenshi.female.nil?
      # @cup.team_categories.each do |cat|
      #   @kenshi.participations.build category: cat
      # end
      # @cup.individual_categories.each do |cat|
      #   @kenshi.participations.build category: cat
      # end
      # @participations_to_teams = @kenshi.participations.select{|p| p.category.is_a? TeamCategory}
      # @participations_to_ind = @kenshi.participations.select{|p| p.category.is_a? IndividualCategory}

      respond_with @kenshi do |format|
        flash.now[:alert] = 'Kenshi not registered'
        format.html { render :new }
        format.js{
          @origin = params[:origin]
          render template: 'layouts/new', layout: false
        }
      end
    end
  end

  def update
    if @kenshi.update_attributes(my_sanitizer)
      notice = t('kenshis.update.flash.notice')
      respond_with @kenshi do |format|
        format.html { redirect_to cup_user_path(@current_cup, @kenshi.user, locale: I18n.locale) , notice: notice }
        format.js {
          @origin = params[:origin]
          flash.now[:notice] = notice
          render '/layouts/create_and_insert_in_select', layout: false
        }
      end
    else
      @title = t('kenshis.edit.title', full_name: @kenshi.full_name)
      @kenshi.valid?
      respond_with @kenshi do |format|
        flash.now[:alert] = "Kenshi not updated: #{@kenshi.errors.full_messages.to_sentence}"
        format.html { render :edit }
        format.js{
          @origin = params[:origin]
          render template: 'layouts/edit', layout: false
        }
      end
    end
  end

  def destroy
    @kenshi.destroy ? notice = t('kenshis.destroy.notice') : alert = t('kenshis.destroy.notice')
    respond_with @kenshi do |format|
      format.html {
        flash[:notice] = notice
        redirect_to cup_user_path(@current_cup, @kenshi.user, locale: I18n.locale)
      }
      format.js{
        flash.now[:notice] = notice if notice.present?
        flash.now[:alert] = alert if alert.present?
        @object = @kenshi
        render 'layouts/destroy'
      }
    end
    rescue Exception => e
      alert = e.message
      alert = alert
      respond_to do |format|
        format.html {
          redirect_to cup_kenshi_path(@current_cup, @kenshi, locale: I18n.locale)
        }
        format.js {
          render('layouts/show_flash')
        }
      end
  end

  private
    def set_user
      @user = User.find params[:user_id] if params[:user_id]
      @products = @cup.products
    end

    def set_variables
      @teams = @cup.teams.incomplete.order(:name)+@current_cup.teams.complete.order(:name)
      # @team_name = params[:kenshi][:team_name] if params[:kenshi] && params[:kenshi][:team_name]
    end

    def my_sanitizer
      params.require(:kenshi).permit(:first_name, :last_name, :email, :dob, :female, :club_id, :club_name, :grade, :club_name, purchases_attributes: [:id, :product_id, :_destroy], individual_category_ids: [], participations_attributes: [:id, :category_type, :category_id, :ronin, :team_name, :_destroy], product_ids: [])
    end
end
