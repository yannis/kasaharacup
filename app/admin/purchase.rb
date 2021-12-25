# frozen_string_literal: true

ActiveAdmin.register Purchase, as: "Purchase" do
  permit_params :product_id, :kenshi_id
end
