module ParticipationsHelper

  def participation_admin_links(participation, nav: nil)
    links = []
    links << destroy_link([@current_cup, participation], {text: "<span class='glyphicon glyphicon-trash'></span>", title: t('participations.destroy.title'), confirm: t('participations.destroy.confirm'), classes: "btn-xs"}) if can?(:destroy, participation)

    return content_tag(:div, class: "admin_links #{nav}", id: "#{participation.class.to_s.tableize}_#{participation.id}_admin_links") do
      for link in links
        concat(link)
      end
    end
  end

end
