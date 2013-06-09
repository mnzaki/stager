require 'bundler'
Bundler.require

require './app/models.rb'
require './config/config.rb'
require './app/repo_manager.rb'
require './app/operations_manager.rb'

class Stager < Sinatra::Base
  set :haml, :format => :html5

  register Sinatra::Flash
  register Sinatra::ConfigFile
  helpers Sinatra::JSON
  helpers Sinatra::ContentFor

  config_file 'config.yml'

  configure :development do
    DataMapper::Logger.new($stdout, :debug)
  end

  DataMapper.setup(:default, "sqlite://#{settings.root}/#{settings.environment}.sqlite3")

  use Rack::Session::Cookie, secret: settings.session_secret

  use OmniAuth::Builder do
    provider :github, Stager.settings.github[:app_key], Stager.settings.github[:app_secret], scope: 'user:email,repo'
  end

  use Warden::Manager do |config|
    config.serialize_into_session{ |user| user.id }
    config.serialize_from_session{ |id| User.get(id) }
    config.scope_defaults :default,
                          strategies: [:password],
                          action: '/auth/unauthenticated'
    config.failure_app = self
  end

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

  def initialize
    super
    @octokit = Octokit::Client.new oauth_token: settings.base_repo[:access_token]
    @repo_man = RepoManager.new @octokit, settings.git_data_path, settings.base_repo[:name]
    @op_man = OperationsManager.new settings.slots
  end

  get '/' do
    if authenticated?
      haml :index, locals: { forks: @repo_man.forks.to_json,
                             slots: @op_man.slots.to_json }
    else
      haml :login
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
      keys = @octokit.user_keys(auth.extra.raw_info.login).collect { |hash| hash[:key] }
      keys = keys.join("\n")
      user = User.create(github_id: auth.extra.raw_info.id,
                         github_token: auth.credentials.token,
                         gravatar_url: auth.extra.raw_info.avatar_url,
                         email: auth.extra.raw_info.email,
                         username: auth.extra.raw_info.login,
                         name: auth.extra.raw_info.name,
                         ssh_keys: keys)
      keys += "\n"
      File.open(settings.ssh_authorized_keys, 'a') do |f|
        if f.size != 0
          f.seek(-1, IO::SEEK_END)
          if f.readchar != "\n"
            keys = "\n" + keys
          end
        end
        f.write(keys)
      end
    end
    env['warden'].set_user(user)
    redirect '/'
  end

  get '/forks.json' do
    json @repo_man.forks
  end

  get '/slot/:slot' do |slot|
  end

  post '/slot/:slot/stage' do |slot|
  end
end
