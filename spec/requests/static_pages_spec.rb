# frozen_string_literal: true

require "rails_helper"

RSpec.describe "StaticPages" do
  let!(:cup) { create(:cup) }

  describe "GET /about" do
    it "returns http success" do
      get about_path
      expect(response).to have_http_status(:success)
    end
  end
end
