# encoding: UTF-8
class ParticipationsController < ApplicationController

  load_and_authorize_resource :participation
  before_filter :check_deadline, only: [:destroy]
  respond_to :html

  def destroy
    @participation.destroy ? notice = t('participations.destroy.notice') : alert = t('participations.destroy.notice')
    respond_with @participation do |format|
      format.html{
        flash[:notice] = notice
        redirect_back_or_default(@participation.kenshi)
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
