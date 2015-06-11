class User < Kendocup::User
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :confirmable, :omniauthable, :omniauth_providers => [:facebook]

  def self.find_for_facebook_oauth(auth, signed_in_resource=nil)
    user = User.where(provider: "facebook", uid: auth.uid).first
    unless user
      birthday = auth.extra.raw_info.birthday.present? ? Date.strptime(auth.extra.raw_info.birthday, '%m/%d/%Y') : nil
      user = User.new(first_name: auth.extra.raw_info.first_name, last_name: auth.extra.raw_info.last_name, female: (auth.extra.raw_info.gender=='female'), dob: birthday, provider: auth.provider, uid: auth.uid, email: auth.info.email, password: Devise.friendly_token[0,20])
      user.skip_confirmation!
      user.save
      user
    end
    return user
  end


  def registered_for_cup?(cup)
    cup.present? && cup.kenshis.where(first_name: self.first_name, last_name: last_name).present?
  end
end
