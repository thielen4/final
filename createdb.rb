# Set up for the application and database. DO NOT CHANGE. #############################
require "sequel"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB = Sequel.connect(connection_string)                                                #
#######################################################################################

# Database schema - this should reflect your domain model
DB.create_table! :gyms do
  primary_key :id
  String :gym
  String :description, text: true
  String :location
  String :phone
end
DB.create_table! :reviews do
  primary_key :id
  foreign_key :gym_id
  Boolean :thumbs
  String :name
  String :email
  String :comments, text: true
end
DB.create_table! :users do
  primary_key :id
  String :name
  String :email
  String :password
end

# Insert initial (seed) data
gyms_table = DB.from(:gyms)

gyms_table.insert(gym: "Rockwell Barbell", 
                    description: "Don't limit yourself: Rockwell Barbell in Chicago is the perfect place to test your strength. There are trainers for every fitness level and ability. Join the Rockwell community today.",
                    location: "2861 North Clybourn Avenue, Chicago, IL 60618",
                    phone: "+17736974871")

gyms_table.insert(gym: "LA Fitness", 
                    description: "LA Fitness is a basic big box gym with too many ammenities.",
                    location: "55 E Randolph St, Chicago, IL 60601",
                    phone: "(312) 281-0113")
