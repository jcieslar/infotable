Rails.application.routes.draw do
  mount Infotable::Engine => "/infotable"

  # Demo routes
  root "home#index"
  resources :users, only: [ :index ]
  resources :products, only: [ :index ]
  resources :authors, only: [ :index ]
  resources :posts, only: [ :index ] do
    collection { match :batch, via: [ :get, :post, :patch, :delete ] }
  end
  resources :comments, only: [ :index ]
end
