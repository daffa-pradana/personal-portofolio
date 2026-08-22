Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # :slug used as the param (not :id) — see Article#to_param.
  resources :articles, only: [ :index, :show ], param: :slug

  # Admin CMS. Article#to_param returns the slug (see app/models/article.rb),
  # so `param: :slug` here just makes the route param name match what's
  # actually in the URL — without it the segment is still a slug, but the
  # controller would be looking it up under params[:id].
  namespace :admin do
    root "dashboard#index"
    resources :articles, param: :slug
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
end
