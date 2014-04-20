module ApplicationHelper

  def mandatory_fields
    "<p class='mandatory_fields'><span class='red_star'>*</span> #{t('layout.form.mandatory')}</p>".html_safe
  end

  def submit_or_cancel_form(f, text=nil)
    link = [f.button(text, class: 'btn')]
    link << t("form.or")
    link << link_to(t("form.cancel"), (session[:return_to].nil? ? root_path : session[:return_to]), accesskey: 'ESC', title: "Cancel #{f.object_name} form", class: "cancel #{request.format == 'application/javascript' ? 'close_div' : ''}")
    link.join(' ').html_safe
  end
end
