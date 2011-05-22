require "rubygems"
require "sinatra"
require "nokogiri"
require "net/http"
require "uri"
require "haml"
require "time"

HN = "http://news.ycombinator.net"
HNBEST = URI.parse "#{HN}/best"
TIME = "%a, %d %b %Y %H:%M:%S %z"  # http://snippets.dzone.com/posts/show/450

configure do
  mime_type :rss, "application/rss+xml"
end

class Item
  attr_accessor :url, :title, :points, :user, :userurl, :comments, :commentsurl,
                :time
end

def parse
  html = Net::HTTP.get HNBEST
  doc = Nokogiri::HTML html
  
  items = []
  even = false
  doc.css("td.title").each do |td|
    if even
      item = Item.new
      
      item.time = Time.now.strftime(TIME)
      
      item.title = td.text.strip
      
      item.url = td.css("a").first["href"]
      if not item.url.include? "://"
        item.url = "#{HN}/#{item.url}"
      end
      
      td = td.parent.next_sibling.css("td.subtext").first
      
      item.points = td.css("span").first.text.split(" ").first.to_i
      
      item.user = td.css("a").first.text.strip
      item.userurl = td.css("a").first["href"]
      item.userurl = "#{HN}/#{item.userurl}"
      
      item.comments = td.css("a")[1].text.split(" ").first.to_i
      item.commentsurl = td.css("a")[1]["href"]
      item.commentsurl = "#{HN}/#{item.commentsurl}"
      
      items << item
      even = false
    else
      even = true
    end
  end
  
  items
end

get "/" do
  content_type :rss
  haml :rss, :escape_html => true,
       :locals => {:link => HNBEST,
                   :last_build => Time.now.strftime(TIME),
                   :items => parse}
end

__END__
@@ rss
!!! XML
%rss{:version => "2.0"}
  %channel
    %title Hacker News Best
    %link= link
    %description This feed contains the Hacker News Best entries.
    %lastBuildDate= last_build
    %language en
    -items.each do |item|
      %item
        %title= item.title
        %link= item.url
        %guid= item.url
        %pubDate= item.time
        %description
          :cdata
            to be done
      

