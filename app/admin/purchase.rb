# frozen_string_literal: true

ActiveAdmin.register Purchase, as: "Purchase" do
  permit_params :product_id, :kenshi_id

  controller do
    def scoped_collection
      super.includes(:kenshi, :product)
    end
  end
end
