require 'sinatra'
require 'mongo'
require 'json'
require 'pry'

# Establish MongoDB connection
MONGO_URL = ENV.fetch('MONGO_URL', 'mongodb://localhost:27017/mydb')
DB = Mongo::Client.new(MONGO_URL)

class App < Sinatra::Base
  get '/' do
    'Sinatra MongoDB API'
  end

  get '/items' do
    content_type :json
    DB[:items].find.to_a.to_json
  end

  post '/items' do
    content_type :json
    data = JSON.parse(request.body.read)
    binding.pry
    result = DB[:items].insert_one(data)
    status 201
    { id: result.inserted_id.to_s }.to_json
  end
end

App.run! if __FILE__ == $0
