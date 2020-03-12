# Set up for the application and database. DO NOT CHANGE. #############################
require "sinatra"                                                                     #
require "sinatra/reloader" if development?                                            #
require "sequel"                                                                      #
require "logger"                                                                      #
require "twilio-ruby"                                                                 #
require "bcrypt"
require "geocoder"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB ||= Sequel.connect(connection_string)                                              #
DB.loggers << Logger.new($stdout) unless DB.loggers.size > 0                          #
def view(template); erb template.to_sym; end                                          #
use Rack::Session::Cookie, key: 'rack.session', path: '/', secret: 'secret'           #
before { puts; puts "--------------- NEW REQUEST ---------------"; puts }             #
after { puts; }                                                                       #
#######################################################################################

gyms_table = DB.from(:gyms)
reviews_table = DB.from(:reviews)
users_table = DB.from(:users)

before do
    @current_user = users_table.where(id: session["user_id"]).to_a[0]
end

get "/" do
    puts gyms_table.all
    @gyms = gyms_table.all.to_a
    view "gyms"
end

get "/gyms/:id" do
    @gym = gyms_table.where(id: params[:id]).to_a[0]
    @reviews = reviews_table.where(gym_id: @gym[:id])
    @reviews_count = reviews_table.where(gym_id: @gym[:id], thumbs: true).count
    @users_table = users_table

    #geocode
    results = Geocoder.search(@gym[:location])
    @lat_long = results.first.coordinates # => [lat, long]
    view "gym"
end

get "/gyms/:id/reviews/new" do
    @gym = gyms_table.where(id: params[:id]).to_a[0]
    view "new_review"
end

get "/gyms/:id/reviews/create" do
    puts params
    @gym = gyms_table.where(id: params["id"]).to_a[0]
    reviews_table.insert(gym_id: params["id"],
                       user_id: session["user_id"],
                       thumbs: params["thumbs"],
                       comments: params["comments"])
    view "create_review"
end

get "/users/new" do
    view "new_user"
end

post "/users/create" do
    puts params
    hashed_password = BCrypt::Password.create(params["password"])
    users_table.insert(name: params["name"], email: params["email"], password: hashed_password)
    view "create_user"
end

get "/logins/new" do
    view "new_login"
end

post "/logins/create" do
    user = users_table.where(email: params["email"]).to_a[0]
    puts BCrypt::Password::new(user[:password])
    if user && BCrypt::Password::new(user[:password]) == params["password"]
        session["user_id"] = user[:id]
        @current_user = user
        view "create_login"
    else
        view "create_login_failed"
    end
end

get "/logout" do
    session["user_id"] = nil
    @current_user = nil
    view "logout"
end