require 'sinatra'

require './config.rb'
require './models.rb'

get '/' do
  body 'it works!'
end

