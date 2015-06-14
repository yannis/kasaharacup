class UsersController < ApplicationController

  load_and_authorize_resource class: User,  param_method: :my_sanitizer
  respond_to :html

  def index
    respond_with @users
  end

  def show
    @title = (@user == current_user ? t("users.show.title.show_self") : t("users.show.title.show", full_name: @user.full_name))
    respond_with @user
  end

  def edit
    if @user == current_user
      @title = @user.registered_for_cup?(@current_cup) ? t("users.edit.title.edit_self") : t("users.edit.title.edit")
    else
      @title = t("users.edit.title.edit_someone", full_name: @user.full_name)
    end
    respond_with @user
  end

  def update
    if @user.update_attributes(my_sanitizer)
      respond_with @user do |format|
        format.html { redirect_back_or_default cup_user_path(@current_cup, @user), notice: 'User updated'}
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
          redirect_to cup_users_path(@current_cup)
        else
          redirect_to root_path
        end
      }
    end
    rescue Exception => e
      alert = e.message
      respond_to do |format|
        format.html {
          redirect_to cup_user_path(@current_cup, @user)
        }
      end
  end

  private

    def my_sanitizer
      if current_user.present?
        if current_user.admin?
          params.require(:user).permit!
        else
          params.require(:user).permit(:first_name, :last_name, :email, :dob, :female, :club_id, :grade, :club_name)
        end
      end
    end
end
