class ParticipationsController < ApplicationController

  load_and_authorize_resource class: Kendocup::Participation, param_method: :my_sanitizer, through: [:user], shallow: true
  before_filter :check_deadline, only: [:destroy]
  before_filter :configure_permitted_parameters, if: :devise_controller?
  respond_to :html

  def destroy
    @participation.destroy ? notice = t('participations.destroy.notice') : alert = t('participations.destroy.notice')
    respond_with @participation do |format|
      format.html{
        flash[:notice] = notice
        redirect_back_or_default([cup, current_user])
      }
      format.js{
        flash.now[:notice] = notice if notice.present?
        flash.now[:alert] = alert if alert.present?
        @object = @participation
        render 'layouts/destroy'
      }
    end
    rescue Exception => e
      alert = e.message
      alert = alert
      respond_to do |format|
        format.html {
          redirect_back_or_default
        }
        format.js {
          render('layouts/show_flash')
        }
      end
  end
end
