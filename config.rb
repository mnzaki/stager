require 'data_mapper'
require 'omniauth'

configure :development do
  DataMapper::Logger.new($stdout, :debug)
end

DataMapper.setup(:default, "sqlite://#{settings.root}/#{settings.environment}.sqlite3")

use Rack::Session::Cookie

use OmniAuth::Builder do
  provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: 'user:email,repo'
end

