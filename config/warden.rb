Warden::Manager.before_failure do |env, opts|
  env['REQUEST_METHOD'] = 'POST'
end

Warden::Strategies.add(:password) do
  def valid?
    params['user'] && params['user']['username'] && params['user']['password']
  end

  def authenticate!
    user = User.first(username: params['user']['username'])

    if !user.nil? and user.authenticate(params['user']['password'])
      success!(user)
    else
      throw(:warden, :message => 'The username or password you entered is invalid.')
    end
  end
end
