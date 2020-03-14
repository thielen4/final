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

#homepage and list of gyms (aka "index")
get "/" do
    puts gyms_table.all
    @gyms = gyms_table.all.to_a
    view "gyms"
end

# gym details (aka "show")
get "/gyms/:id" do
    @gym = gyms_table.where(id: params[:id]).to_a[0]
    @reviews = reviews_table.where(gym_id: @gym[:id])
    @users_table = users_table

    #geocode
    results = Geocoder.search(@gym[:location])
    @georesults = results.first.coordinates # => [lat, long]
    @lat = @georesults[0]
    @long = @georesults[1]
    @lat_long = "#{@lat},#{@long}"
    view "gym"
end

# display the review form (aka "new")
get "/gyms/:id/reviews/new" do
    @gym = gyms_table.where(id: params[:id]).to_a[0]
    view "new_review"
end

# receive the submitted rsvp form (aka "create")
get "/gyms/:id/reviews/create" do
    puts params
    @gym = gyms_table.where(id: params["id"]).to_a[0]
    reviews_table.insert(gym_id: params["id"],
                       user_id: session["user_id"],
                       thumbs: params["thumbs"],
                       comments: params["comments"])
    redirect "/gyms/#{@gym[:id]}"
end

# display the review form (aka "edit")
get "/rsvps/:id/edit" do
    puts "params: #{params}"

    @review = reviews_table.where(id: params["id"]).to_a[0]
    @gym = gyms_table.where(id: @rreview[:gym_id]).to_a[0]
    view "edit_review"
end

# receive the submitted review form (aka "update")
post "/reviews/:id/update" do
    puts "params: #{params}"

    # find the review to update
    @review = reviews_table.where(id: params["id"]).to_a[0]
    # find the review's event
    @gym = reviews_table.where(id: @review[:gym_id]).to_a[0]

    if @current_user && @current_user[:id] == @review[:id]
        reviews_table.where(id: params["id"]).update(
            going: params["going"],
            comments: params["comments"]
        )

        redirect "/gymss/#{@gym[:id]}"
    else
        view "error"
    end
end

# delete the review (aka "destroy")
get "/reviews/:id/destroy" do
    puts "params: #{params}"

    review = reviews_table.where(id: params["id"]).to_a[0]
    @gym = gyms_table.where(id: review[:gym_id]).to_a[0]

    reviews_table.where(id: params["id"]).delete

    redirect "/gyms/#{@gym[:id]}"
end

# display the signup form (aka "new")
get "/users/new" do
    view "new_user"
end

# receive the submitted signup form (aka "create")
post "/users/create" do
    puts "params: #{params}"

    # if there's already a user with this email, skip!
    existing_user = users_table.where(email: params["email"]).to_a[0]
    if existing_user
        view "error"
    else
        users_table.insert(
            name: params["name"],
            email: params["email"],
            password: BCrypt::Password.create(params["password"])
        )

        redirect "/logins/new"
    end
end

# display the login form (aka "new")
get "/logins/new" do
    view "new_login"
end

# receive the submitted login form (aka "create")
post "/logins/create" do
    puts "params: #{params}"

    # step 1: user with the params["email"] ?
    @user = users_table.where(email: params["email"]).to_a[0]

    if @user
        # step 2: if @user, does the encrypted password match?
        if BCrypt::Password.new(@user[:password]) == params["password"]
            # set encrypted cookie for logged in user
            session["user_id"] = @user[:id]
            redirect "/"
        else
            view "create_login_failed"
        end
    else
        view "create_login_failed"
    end
end


# logout user
get "/logout" do
    # remove encrypted cookie for logged out user
    session["user_id"] = nil
    redirect "/logins/new"
end