# frozen_string_literal: true

class PurchasesController < ApplicationController
  load_and_authorize_resource class: Purchase
  before_action :check_deadline, only: [:destroy]
  respond_to :html

  def destroy
    @purchase.destroy ? notice = t("purchases.destroy.notice") : alert = t("purchases.destroy.notice")
    respond_with @purchase do |format|
      format.html {
        flash[:notice] = notice
        redirect_back_or_default(current_user)
      }
      format.js {
        flash.now[:notice] = notice if notice.present?
        flash.now[:alert] = alert if alert.present?
        @object = @purchase
        render "layouts/destroy"
      }
    end
  rescue => e
    alert = e.message
    alert = alert
    respond_to do |format|
      format.html {
        redirect_back_or_default
      }
      format.js {
        render("layouts/show_flash")
      }
    end
  end
end
