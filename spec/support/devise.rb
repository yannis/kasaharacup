RSpec.configure do |config|
  config.include Devise::TestHelpers, type:  :controller

  def sign_in_admin_user(user=nil)
    @request.env["devise.mapping"] = Devise.mappings[:user]
    sign_out :user
    @admin = user.presence || FactoryGirl.create( :user, :last_name => "admin_user", :admin => true)
    sign_in @admin
  end

  def sign_in_basic_user(user=nil)
    @request.env["devise.mapping"] = Devise.mappings[:user]
    sign_out :user
    @basic = user.presence || FactoryGirl.create(:user, :last_name => 'basic_user', :admin => false)
    sign_in @basic
  end
end
