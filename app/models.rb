require 'dm-timestamps'

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
  # full fork name user/repo-name
  property :current_fork,   String
  property :current_branch, String
  property :port,           Integer
  property :app_pid,        Integer, default: -1
  # sidekiq job id
  property :job_id,         String, default: ''
  #timestamps :at    # Add created_at and updated_at
  #timestamps :on    # Add created_on and updated_on
  property :created_at, DateTime
  property :created_on, Date
  property :updated_at, DateTime
  property :updated_on, Date
end

DataMapper.finalize
