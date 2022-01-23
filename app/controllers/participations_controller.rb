# frozen_string_literal: true

class ParticipationsController < ApplicationController
  load_and_authorize_resource :user
  load_and_authorize_resource :participation, param_method: :my_sanitizer, through: :user, shallow: true

  before_action :check_deadline, only: [:destroy]
  before_action :configure_permitted_parameters, if: :devise_controller?

  def destroy
    @participation.destroy ? notice = t("participations.destroy.notice") : alert = t("participations.destroy.notice")
    respond_with @participation do |format|
      format.html {
        flash[:notice] = notice
        redirect_back_or_to([cup, current_user])
      }
      format.js {
        flash.now[:notice] = notice if notice.present?
        flash.now[:alert] = alert if alert.present?
        @object = @participation
        render "layouts/destroy"
      }
    end
  rescue => e
    alert = e.message
    respond_to do |format|
      format.html {
        redirect_back_or_to(cup_participation_path(@participation.cup, @participation))
      }
      format.js {
        render("layouts/show_flash")
      }
    end
  end
end
