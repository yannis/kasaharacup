class MailingList

  def self.user_subscribed?(user)
    begin
      if Rails.env.test?
        return true
      else
        user_info = MAILINGLIST.lists.member_info({:id => ENV['MAILCHIMP_LIST_ID'], :emails => [{:email => user.email}]})
        # Rails.logger.info "User #{user.full_name} already subscribed to the mailchimp list"
        # byebug
        return user_info['success_count'] > 0
      end
    rescue Exception => e
      notify_airbrake(e) if Rails.env.production?
      Rails.logger.error "Mailchimp unreachable: #{e.message}"
      true
    end
  end

  def self.subscribe(user)
    unless self.user_subscribed?(user)
      Rails.logger.info "Subscribing #{user.full_name} to mailchimp list"
      MAILINGLIST.lists.subscribe({id: ENV["MAILCHIMP_LIST_ID"], email: {email: user.email}, merge_vars: {:FNAME => user.first_name, :LNAME => user.last_name}, double_optin: false}) unless ["test"].include?(Rails.env)
      Rails.logger.info "User #{user.full_name} subscribed to the mailchimp list"
    end
  end

  # def self.unsubscribe(user)
  #   # if Rails.env.test?
  #   #   return true
  #   # else
  #     gb = Gibbon.new
  #     gb.list_unsubscribe({:id => (Rails.env.production? ? ENV['MAILCHIMP_LIST_ID'] : ENV['MAILCHIMP_LIST_TEST_ID']), :email_address => user.email}) if self.user_subscribed?(user)
  #   # end
  # end
end
