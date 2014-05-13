Rails.application.routes.draw do

  devise_for :users, controllers: {
      registrations: "users/registrations",
      # skip: :omniauth_callbacks
      omniauth_callbacks: "users/omniauth_callbacks"
    }

  scope "(:year)", year: /2014/ do |year|
    scope "(:locale)", locale: /fr|en/ do |locale|

      resources :cups, only: :show
      resources :kenshis do
        # collection do
        #   match 'category/:category/', :to => :index
        # end
        get :autocomplete_kenshi_club, on: :collection
      end

      resources :participations, only: [:destroy]

      resources :teams, only: [:index, :show]

      resources :users, only: [:index, :show, :edit, :update, :destroy] do
        resources :kenshis do
          member do
            get :duplicate, to: 'kenshis#new'
          end
        end
      end

      get 'auth/:provider/callback', to: 'sessions#create'
      get 'auth/failure', to: redirect('/')
      # match 'signout', to: 'devise/sessions#destroy', as: 'signout'
      devise_scope :user do
        get 'signout', to: 'devise/sessions#destroy', as: 'signout'
      end

      resource :mailing_list, :only => [:new, :destroy]
      root to: "cups#show"
    end
    get '/', to: redirect("#{Date.current.year}/#{I18n.locale}")
  end

  # match "/users/auth/:provider", constraints: { provider: /google|facebook/ }, to: "devise/omniauth_callbacks#passthru", as: :omniauth_authorize, via: [:get, :post]
  # match "/users/auth/:action/callback", constraints: { action: /google|facebook/ }, to: "devise/omniauth_callbacks", as: :omniauth_callback, via: [:get, :post]



  # root to: "cups#show", year: Date.current.year, locale: I18n.locale
  # root to: "cups#show", year: Date.current.year, locale: I18n.locale

  ActiveAdmin.routes(self)
end
