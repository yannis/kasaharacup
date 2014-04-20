class UsersController < ApplicationController

  load_and_authorize_resource :user,  param_method: :my_sanitizer
  respond_to :html

  def index
    respond_with @users
  end

  def show
    respond_with @user
  end

  # def new
  #   if @user == current_user
  #     @title = "Inscrivez quelq'un à la compétition"
  #   end
  #   respond_with @user
  # end

  def edit
    if @user == current_user
      @title = @user.registered? ? t("users.edit.title.edit_self") : t("users.edit.title.edit")
    else
      @title = t("users.edit.title.edit_someone", full_name: @user.full_name)
    end
    respond_with @user
  end

  def create
    if @user.save
      respond_with @user do |format|
        format.html { redirect_to new_user_enrollment_path(@user, locale: I18n.locale), notice: 'User registered' }
        format.js {
          @origin = params[:origin]
          flash.now[:notice] = 'Kenshi registered'
          render '/layouts/create_and_insert_in_select', layout: false
        }
      end
    else
      respond_with @user do |format|
        flash.now[:alert] = 'User not created'
        format.html { render :new }
        format.js{
          @origin = params[:origin]
          render template: 'layouts/new', layout: false
        }
      end
    end
  end

  def update
    if @user.update_attributes(params[:user])
      respond_with @user do |format|
        format.html { redirect_back_or_default user_path(@user, locale: I18n.locale) , notice: 'User updated' }
        format.js {
          @origin = params[:origin]
          flash.now[:notice] = 'User updated'
          render '/layouts/create_and_insert_in_select', layout: false
        }
      end
    else
      respond_with @user do |format|
        flash.now[:alert] = 'User not updated'
        format.html { render :edit }
        format.js{
          @origin = params[:origin]
          render template: 'layouts/edit', layout: false
        }
      end
    end
  end

  def destroy
    @user.destroy ? notice = "User destroyed" : alert = "Unable to destroy user"
    respond_with @user do |format|
      format.html{
        if current_user.admin?
          redirect_to(users_path locale: I18n.locale)
        else
          redirect_to(root_path)
        end
      }
      format.js{
        flash.now[:notice] = notice if notice.present?
        flash.now[:alert] = alert if alert.present?
        @object = @user
        render 'layouts/destroy'
      }
    end
    rescue Exception => e
      alert = e.message
      alert = alert
      respond_to do |format|
        format.html {
          redirect_to @user
        }
        format.js {
          render('layouts/show_flash')
        }
      end
  end

  private

    def my_sanitizer
      if current_user.present?
        if current_user.admin?
          params.require(:kenshi).permit!
        else
          params.require(:kenshi).permit(:first_name, :last_name, :email, :dob, :female, :club_id, :grade, :new_club_name, participations_attributes: [:category_type, :category_id, :ronin, :team_id, :new_team_name])
        end
      end
    end
end
