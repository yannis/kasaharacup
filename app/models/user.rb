class User < Kendocup::User
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable, :confirmable

  after_save :register_to_mailing_list

  def registered_for_cup?(cup)
    cup.present? && cup.kenshis.where(first_name: self.first_name, last_name: last_name).present?
  end


private

  def register_to_mailing_list
    MAILINGLIST.lists.subscribe({id: ENV["MAILCHIMP_LIST_ID"], email: {email: self.email}, merge_vars: {:FNAME => self.first_name, :LNAME => self.last_name}, double_optin: false}) unless ["test"].include?(Rails.env)
  end
end
