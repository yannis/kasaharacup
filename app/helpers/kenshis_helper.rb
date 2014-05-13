module KenshisHelper

  def current_user_admin_or_owner?(kenshi)
    current_user.present? && (current_user.admin? || kenshi.user == current_user)
  end

  def kenshi_admin_links(kenshi, nav: nil)
    links = []
    links << edit_link(kenshi)if can?(:update, kenshi)
    links << destroy_link(kenshi, {title: t('kenshis.destroy.title'), confirm: t('kenshis.destroy.confirm')}) if can?(:destroy, kenshi)

    links << link_to("<i class='fa fa-files-o'></i> Duplicate".html_safe, duplicate_user_kenshi_path(kenshi.user, kenshi), class: "btn btn-default") if can?(:create, Kenshi) && current_user_admin_or_owner?(kenshi)

    return content_tag(:div, class: "admin_links #{nav}", id: "#{kenshi.class.to_s.tableize}_#{kenshi.id}_admin_links") do
      for link in links
        concat(link)
      end
    end
  end

end
