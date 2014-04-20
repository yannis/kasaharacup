# You can read about this gist at: http://wealsodocookies.com/posts/how-to-test-facebook-login-using-devise-omniauth-rspec-and-capybara

def set_omniauth(user, opts = {})
  default = {:provider => :facebook,
             :uuid     => "1234",
             :facebook => {
                            :email => user.email,
                            :gender => user.female? ? 'Female' : 'Male',
                            :first_name => user.first_name,
                            :last_name => user.last_name
                          }
            }

  credentials = default.merge(opts)
  provider = credentials[:provider]
  user_hash = credentials[provider]

  OmniAuth.config.test_mode = true

  OmniAuth.config.mock_auth[provider] = {
    'uid' => credentials[:uuid],
    "extra" => {
    "user_hash" => {
      "email" => user_hash[:email],
      "first_name" => user_hash[:first_name],
      "last_name" => user_hash[:last_name],
      "gender" => user_hash[:gender]
      }
    }
  }
end

def set_invalid_omniauth(user, opts = {})
  
  credentials = { :provider => :facebook,
                  :invalid  => :invalid_crendentials
                 }.merge(opts)
  
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[credentials[:provider]] = credentials[:invalid]

end 