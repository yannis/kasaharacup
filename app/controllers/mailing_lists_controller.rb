class MailingListsController < ApplicationController

  def new
    authorize! :manage, 'mailing_list'
    respond_to do |format|
      format.js
      format.html
    end
  end

  def destroy
    authorize! :manage, 'mailing_list'
    if MailingList.unsubscribe current_user
      session['mailing_list'] = MailingList.user_subscribed?(current_user)
      flash[:notice] = "You're unsubscribed from our mailing list"
    else
      flash[:alert] = "Unable to unsubscribe you… the server might be not responding. Please try again soon…"
    end
    redirect_back_or_default root_path
  end
end
