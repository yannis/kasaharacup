# frozen_string_literal: true

module ParticipationsHelper
  def participation_admin_links(participation, nav: nil)
    links = []
    if can?(
      :destroy, participation
    )
      links << destroy_link([@current_cup, participation],
        {text: "Destroy", title: t("participations.destroy.title"),
         data: {turbo_method: :delete, turbo_confirm: t("participations.destroy.confirm")}}, classes: "btn-xs")
    end

    content_tag(:div, class: "admin_links #{nav}",
      id: "#{participation.class.to_s.tableize}_#{participation.id}_admin_links") do
      links.each do |link|
        concat(link)
      end
    end
  end
end
