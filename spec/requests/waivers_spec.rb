# frozen_string_literal: true

require "rails_helper"

describe("WaiversController") do
  describe "GET /show" do
    let(:cup) { create(:cup, start_on: Date.new(2019, 8, 1), end_on: Date.new(2019, 8, 2)) }

    it "renders the waiver" do
      get cup_waiver_path(cup)

      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"])
        .to eq "inline; filename=\"junior_waiver_2019.pdf\"; filename*=UTF-8''junior_waiver_2019.pdf"
      expect(response.content_type).to eq("application/pdf")
    end
  end
end
