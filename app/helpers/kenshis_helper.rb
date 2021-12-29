# frozen_string_literal: true

module KenshisHelper
  def kenshi_admin_links(kenshi, options: {})
    links = []
    if can?(:update, kenshi)
      links << edit_link([@current_cup, kenshi], classes: "btn-xs")
    end
    if can?(:destroy, kenshi)
      links << destroy_link([@current_cup, kenshi],
        {title: t("kenshis.destroy.title"), confirm: t("kenshis.destroy.confirm"), classes: "btn-xs"})
    end
    if can?(:create, Kenshi) && current_user_admin_or_owner?(kenshi)
      links << link_to("<i class='fa fa-files-o'></i> Duplicate".html_safe,
        duplicate_cup_user_kenshi_path(@current_cup, kenshi.user, kenshi), class: "btn btn-default btn-xs")
    end

    classes = options.fetch(:class, "")

    content_tag(:div, class: "admin_links #{classes} btn-group",
id: "#{kenshi.class.to_s.tableize}_#{kenshi.id}_admin_links") do
      links.each do |link|
        concat(link)
      end
    end
  end
end
