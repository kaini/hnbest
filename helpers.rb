helpers do
  def update_database
    html = Net::HTTP.get URI.parse(HNBEST_URI)
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
        
        item[:user] = td.css("a").first.text.strip
        item[:userurl] = td.css("a").first["href"]
        item[:userurl] = "#{HN_URI}/#{item[:userurl]}"
        
        item[:commentsurl] = td.css("a")[1]["href"]
        item[:commentsurl] = "#{HN_URI}/#{item[:commentsurl]}"
        
        updated = items.filter(:url => item[:url]).update(:last_seen_time => Time.now)
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

  def fetch_items
    lu = last_update
    if lu
      if lu < Time.now - UPDATE_INTERVAL
        update_database
      end
    else
      update_database
    end
    
    DB[:items].order(:post_time).all
  end
end