# frozen_string_literal: true

ActiveAdmin.register Club, as: "Club" do
  permit_params :name
end
