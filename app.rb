require 'bundler'
Bundler.require

require './app/models.rb'
require './config/config.rb'

class Stager < Sinatra::Base
  set :haml, :format => :html5

  configure :development do
    DataMapper::Logger.new($stdout, :debug)
  end

  DataMapper.setup(:default, "sqlite://#{settings.root}/#{settings.environment}.sqlite3")

  use Rack::Session::Cookie, secret: ENV['SESSION_SECRET']

  use OmniAuth::Builder do
    provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], scope: 'user:email,repo'
  end

  use Warden::Manager do |config|
    config.serialize_into_session{ |user| user.id }
    config.serialize_from_session{ |id| User.get(id) }
    config.scope_defaults :default,
                          strategies: [:password],
                          action: '/auth/unauthenticated'
    config.failure_app = self
  end

  register Sinatra::Flash

  def authenticate!
    env['warden'].authenticate!
    env['warden'].user
  end

  def current_user
    @current_user ||= env['warden'].user
  end

  def authenticated?
    !env['warden'].user.nil?
  end

  get '/' do
    if authenticated?
      current_user.username
    else
      haml :index
    end
  end

  get '/auth/login' do
    haml :login
  end

  post '/auth/login' do
    authenticate!

    if session[:return_to].nil?
      redirect '/'
    else
      redirect session[:return_to]
    end
  end

  get '/auth/logout' do
    env['warden'].logout
    redirect '/'
  end

  post '/auth/unauthenticated' do
    session[:return_to] = env['warden.options'][:attempted_path]
    flash[:error] = env['warden.options'][:message]
    redirect '/auth/login'
  end

  get '/auth/github/callback' do
    auth = request.env['omniauth.auth']
    # FIXME
    return 500 if auth.nil?

    user = User.first(github_id: auth.extra.raw_info.id)
    if user.nil?
      user = User.create(github_id: auth.extra.raw_info.id,
                         github_token: auth.credentials.token,
                         gravatar_url: auth.extra.raw_info.avatar_url,
                         email: auth.extra.raw_info.email,
                         username: auth.extra.raw_info.login,
                         name: auth.extra.raw_info.name)
    end
    env['warden'].set_user(user)
    redirect '/'
  end
end
