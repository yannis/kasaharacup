module PurchasesHelper

  def purchase_admin_links(purchase, nav: nil)
    links = []
    if can?(:destroy, purchase)
      links << destroy_link([@current_cup, purchase], {text: "<span class='glyphicon glyphicon-trash'></span>", title: t('purchases.destroy.title'), confirm: t('purchases.destroy.confirm'), classes: "btn-xs"})
    end

    return content_tag(:div, class: "admin_links #{nav}", id: "#{purchase.class.to_s.tableize}_#{purchase.id}_admin_links") do
      for link in links
        concat(link)
      end
    end
  end

end
