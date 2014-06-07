ActiveAdmin.register Product do
  permit_params :name_en, :name_fr, :description_en, :description_fr, :cup_id, :event_id, :fee_chf, :fee_eu
end
