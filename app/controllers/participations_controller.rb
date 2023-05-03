# frozen_string_literal: true

class ParticipationsController < ApplicationController
  load_and_authorize_resource :user
  load_and_authorize_resource :participation, param_method: :my_sanitizer, through: :user, shallow: true

  before_action :check_deadline, only: [:destroy]
  before_action :configure_permitted_parameters, if: :devise_controller?

  def destroy
    @participation.destroy ? notice = t(".notice") : alert = t(".alert")
    flash[:notice] = notice if notice.present?
    flash[:alert] = alert if alert.present?
    redirect_back_or_to(cup_user_path(@participation.cup), status: :see_other)
  rescue => e
    flash[:alert] = e.message
    redirect_back_or_to(cup_participation_path(@participation.cup, @participation), status: :see_other)
  end
end
