require "net/http"
require "uri"
require "time"

require_relative "helpers"

set :haml, escape_html: true

HN_URI = "http://news.ycombinator.net"
HNBEST_URI = "#{HN_URI}/best"

# 02 Oct 2002 15:00:00 +0200
TIME_FORMAT = "%m %b %Y %H:%M:%S %z"  

SELF_URI = "http://hnbest.heroku.com/rss"

UPDATE_INTERVAL = 600

#####################
### DATABASE PART ###
#####################

DB = Sequel.connect(ENV['DATABASE_URL'] || "sqlite:///tmp/hnbest.db")
DB.loggers << Logger.new($stdout)
DB.create_table? :items do
  primary_key :id
  String :url, :null => false
  String :title, :null => false
  Integer :points, :null => false
  String :user, :null => false
  String :userurl, :null => false
  String :commentsurl, :null => false
  DateTime :post_time, :null => false
  DateTime :last_seen_time, :null => false
end
DB.create_table? :last_update do
  primary_key :id
  DateTime :last_update, :null => false
end

configure do
  mime_type :rss, "application/rss+xml"
end

get "/" do
  haml :index
end

get "/rss" do
  content_type :rss
  items = fetch_items
  lu = last_update
  haml :rss,
       :locals => {:link => HNBEST_URI,
                   :items => items,
                   :self_href => SELF_URI,
                   :last_build => lu,
                   :time_format => TIME_FORMAT}
end