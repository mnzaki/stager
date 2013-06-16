require './app.rb'
require 'sidekiq/web'
require 'sidekiq_status/web'

map '/' do
  run Stager.new
end

map '/sidekiq' do
  run Sidekiq::Web
end
