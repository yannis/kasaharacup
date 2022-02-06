# frozen_string_literal: true

# Hotwire's Turbo library intercepts forms automatically so Devise needs a few tweaks to work with it.
# This controller is part of the solution to render html templates when getting a turbo stream request.
# See https://gorails.com/episodes/devise-hotwire-turbo for details.
class TurboController < ApplicationController
  class Responder < ActionController::Responder
    def to_turbo_stream
      controller.render(options.merge(formats: :html))
    rescue ActionView::MissingTemplate => error
      if get?
        raise error
      elsif has_errors? && default_action
        render rendering_options.merge(formats: :html, status: :unprocessable_entity)
      else
        redirect_to("/")
      end
    end
  end

  self.responder = Responder
  respond_to :html, :turbo_stream
end
