# frozen_string_literal: true

class WaiversController < ApplicationController
  load_and_authorize_resource :cup, find_by: :year, class: "Cup"

  def show
    pdf = WaiverPdf.new(@cup)
    send_pdf pdf, filename: "junior_waiver_#{@cup.year}"
  end
end
