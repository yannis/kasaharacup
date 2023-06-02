# frozen_string_literal: true

class WaiversController < ApplicationController
  load_and_authorize_resource :cup, find_by: :year, class: "Cup"

  def show
    pdf = WaiverPdf.new(@cup)
    send_data pdf.render, filename: "junior_waiver_#{@cup.year}.pdf",
      type: "application/pdf",
      disposition: "inline",
      page_size: "A4"
  end
end
