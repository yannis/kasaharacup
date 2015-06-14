Rails.application.routes.draw do
  mount Kendocup::Engine => "/"

  devise_scope :user do
    providers = Regexp.union(Devise.omniauth_providers.map(&:to_s))
    match 'users/auth/:provider',
      constraints: { provider: providers },
      to: 'omniauth_callbacks#passthru',
      as: :omniauth_authorize,
      via: [:get, :post]

    match 'users/auth/:action/callback',
      constraints: { action: providers },
      controller: 'users/omniauth_callbacks',
      as: :omniauth_callback,
      via: [:get, :post]

    # get 'signout', to: 'devise/sessions#destroy', as: 'signout'
    # get 'signin', to: 'devise/sessions#new', as: 'signin'
    # get 'signup', to: 'devise/registrations#new', as: 'signup'
  end
  devise_for :users, class_name: 'User', module: :devise, except: [:omniauth_callbacks], controllers: {registrations: "users/registrations"}

  scope ":locale", locale: /fr|en/ do |locale|

    resources :cups, only: [:index, :show] do
      resources :headlines, only: [:index, :show]
      resources :kenshis do
        get :autocomplete_kenshi_club, on: :collection
      end

      resources :participations, only: [:destroy]
      resources :purchases, only: [:destroy]
      resources :teams, only: [:index, :show]
      resources :users do
        resources :kenshis do
          member do
            get :duplicate, to: 'kenshis#new'
          end
        end
      end
    end

    # resources :users

    resource :mailing_list, only: [:new, :destroy]
    root to: "cups#show"
    get '/', to: redirect(Date.current.year.to_s)

  end

  get '/', to: redirect(I18n.locale.to_s)

  ActiveAdmin.routes(self)
end
