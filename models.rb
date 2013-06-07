require 'data_mapper'

DataMapper.setup(:default, "sqlite://#{settings.root}/#{settings.environment}.sqlite3")

class User
  include DataMapper::Resource

  property :id,         Serial
  property :username,   String
end
