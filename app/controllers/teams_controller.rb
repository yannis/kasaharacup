class TeamsController < ApplicationController
  load_and_authorize_resource :cup, find_by: :year, class: Kendocup::Cup
  load_and_authorize_resource :team, class: Kendocup::Team
  respond_to :html

  def index
    @ronins = @cup.participations.ronins.map(&:kenshi)
    @teams = @cup.teams.order(:name)
    respond_with @teams
  end

  def show
    respond_with @team
  end

  def destroy
    @team.destroy ? notice = t('teams.destroy.notice') : alert = t('teams.destroy.notice')
    respond_with @team do |format|
      format.html {
        flash[:notice] = notice
        redirect_to cup_teams_path(@cup)
      }
      format.js{
        flash.now[:notice] = notice if notice.present?
        flash.now[:alert] = alert if alert.present?
        @object = @team
        render 'layouts/destroy'
      }
    end
    rescue Exception => e
      alert = e.message
      alert = alert
      respond_to do |format|
        format.html {
          redirect_to cup_team_path(@cup, @team)
        }
        format.js {
          render('layouts/show_flash')
        }
      end
  end
end
