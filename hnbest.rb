require "rubygems"
require "sinatra"
require "nokogiri"
require "net/http"
require "uri"
require "haml"
require "time"
require "sequel"
require "logger"

HN_URI = "https://news.ycombinator.com"
HNBEST_URI = "#{HN_URI}/best"

# 02 Oct 2002 15:00:00 +0200
TIME_FORMAT = "%d %b %Y %H:%M:%S %z"  

SELF_URI = "http://hnbest.herokuapp.com/rss"

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
  Integer :real_points, :null => false
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

def update_database
  uri = URI.parse(HNBEST_URI)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  html = http.request(Net::HTTP::Get.new(uri.request_uri)).body

  doc = Nokogiri::HTML html
  
  items = DB[:items]
  even = false
  doc.css("td.title").each do |td|
    if even
      item = {}
      
      item[:title] = td.text.strip
      
      item[:url] = td.css("a").first["href"]
      if not item[:url].include? "://"
        item[:url] = "#{HN_URI}/#{item[:url]}"
      end
      
      td = td.parent.next_sibling.css("td.subtext").first
      
      item[:points] = td.css("span").first.text.split(" ").first.to_i
      item[:real_points] = item[:points]
      
      item[:user] = td.css("a").first.text.strip
      item[:userurl] = td.css("a").first["href"]
      item[:userurl] = "#{HN_URI}/#{item[:userurl]}"
      
      item[:commentsurl] = td.css("a")[1]["href"]
      item[:commentsurl] = "#{HN_URI}/#{item[:commentsurl]}"
      
      updated = items.filter(:url => item[:url]).update(:last_seen_time => Time.now, :real_points => item[:real_points])
      if updated == 0
        item[:post_time] = Time.now
        item[:last_seen_time] = Time.now
        items.insert(item)
      end
      
      even = false
    else
      even = true
    end
  end
  
  killtime = Time.now - UPDATE_INTERVAL
  items.filter{last_seen_time < killtime}.delete
  
  last_update = DB[:last_update]
  last_update.delete
  last_update.insert(:last_update => Time.now)
  
  nil
end

def last_update
  lu = DB[:last_update].select(:last_update).all.first
  if lu
    lu[:last_update]
  else
    Time.now - 2 * UPDATE_INTERVAL
  end
end

def fetch_items(count)
  if last_update < Time.now - UPDATE_INTERVAL
    update_database
  end
  
  DB.from(DB[:items].order(Sequel.desc(:real_points)).limit(count).as(:posts)).order(Sequel.desc(:post_time)).all
end

####################
### SINATRA PART ###
####################

configure do
  mime_type :rss, "application/rss+xml"
end

get "/" do
  haml :index, :escape_html => true
end

get "/rss" do
  if params[:count]
    item_count = params[:count].to_i
  else
    item_count = 30
  end
  if item_count <= 0
    item_count = 30
  end

  content_type :rss
  items = fetch_items item_count
  lu = last_update
  haml :rss, :escape_html => true,
       :locals => {:link => HNBEST_URI,
                   :items => items,
                   :self_href => SELF_URI,
                   :last_build => lu,
                   :time_format => TIME_FORMAT}
end

#################
### HAML PART ###
#################
__END__
@@ index
!!! 5
%html
  %head
    %title Hacker News Best RSS
    %meta{:name => "keywords",
          :content => "hacker, news, hackernews, rss, best"}
    %link{:rel => "alternate",
          :type => "application/rss+xml",
          :title => "Hacker News Best",
          :href => "/rss"}
  %body
    %h1
      Hacker News Best
      %a{:href => "/rss"} RSS
    %p
      You can append "?count=10" to reduce the amount of news items. The default is 30.
    %p
      %a{:href => "https://github.com/kaini/hnbest"} Github
@@ rss
!!! XML
%rss{:version => "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom"}
  %channel
    %title Hacker News Best
    %link= link
    <atom:link href="#{self_href}" rel="self" type="application/rss+xml" />
    %description This feed contains the Hacker News Best entries.
    %lastBuildDate= last_build.strftime(time_format)
    %language en
    -items.each do |item|
      %item
        %title= item[:title]
        %link= item[:url]
        %guid= item[:url]
        %pubDate= item[:post_time].strftime(time_format)
        %description
          <![CDATA[
          %p
            Started with
            = item[:points]
            points; by
            %a{:href => item[:userurl]}= item[:user]
          %p
            %a{:href => item[:commentsurl]} Comments
          ]]>
      

