require 'rails_helper'
RSpec.describe MailingList, type: :model do
  let(:user){create :kendocup_user, email: "yannisjaquet@mac.com"}
  it {expect(MailingList.user_subscribed?(user)).to eql true}
end
