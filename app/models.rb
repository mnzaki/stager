class User
  include DataMapper::Resource
  include BCrypt

  property :id,           Serial, key: true
  property :github_id,    Integer
  property :github_token, String, length: 50
  property :ssh_keys,     Text
  property :gravatar_url, String, length: 200
  property :username,     String, length: 2..50
  property :email,        String, length: 60, format: :email_address
  property :password,     BCryptHash
  property :name,         String, length: 60

  def authenticate(attempted_password)
    self.password == attempted_password
  end
end

class ActiveSlot
  include DataMapper::Resource

  property :name,           String, key: true
  property :current_fork,   String
  property :current_branch, String
  property :port,           Integer
  property :pid,            Integer
end

DataMapper.finalize
