# see http://pupeno.com/2010/08/29/show-a-devise-log-in-form-in-another-page/
module ContentHelper
  def resource_name
    :user
  end

  def resource
    @resource ||= User.new
  end

  def resource_class
    devise_mapping.to
  end

  def devise_mapping
    @devise_mapping ||= Devise.mappings[:user]
  end
end
