class User
  include DataMapper::Resource
  include BCrypt

  property :id,         Serial
  property :username,   String
  property :password,   BCryptHash

  def authenticate(attempted_password)
    self.password == attempted_password
  end
end

DataMapper.finalize
