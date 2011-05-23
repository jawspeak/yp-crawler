#!/usr/bin/env ruby

require 'mechanize'
require 'csv'
require 'cgi'

class Search

  def initialize(filename)
    @terms = %w(Dock+Builders Marina Boat+Dock Dock+Pilings Marine+Contractor Yacht+Club Boat+Lift)
#    @states = %w(AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY)
    @states = %w(FL)
    @filename = filename
  end

  def run
    puts "Extracting data, saving to " + @filename
    CSV.open(@filename, 'w') {|f| f << %w(state_searched_with first_search_term company_name neighborhood address locality zip state phone website categories) }
    @states.each do |state|
      agent = Mechanize.new
      already_saved = {}
      @terms.each do |term|
        search(agent.get("http://www.yellowpages.com/fl/boat-dock?g=#{state}&q=#{term}"), already_saved, state, term)
      end
    end
  end

  def search(page, already_saved, state, term)
    begin      
      extract(page, already_saved, state, term)
      next_link = page.links.find { |l| l.text == 'Next' }
      puts "Extracting #{state} #{term} " + next_link.attributes['href'].match('.*(page=\d+).*')[1] if next_link
    end while next_link && page = next_link.click
  end
  
  def extract(page, already_saved, state_searched_with, first_search_term)  
    results = []
    page.search('.listing_content').each do |l|
      company_name = l.search('.business-name').text.strip
      neighborhood = l.search('.business-neighborhoods').text.strip.gsub(/[\r\n]+/,'')
      categories = l.search('.business-categories').text.strip.gsub(/[\r\n]+/,'')
      address = l.search('.street-address').text.strip
      key = "#{company_name}_#{address}"
      locality = l.search('.locality').text.strip
      zip = l.search('.postal-code').text.strip
      state = l.search('.region').text.strip
      phone = l.search('.business-phone').text.strip
      website = extract_website(l)      
      results << [state_searched_with, first_search_term, company_name, neighborhood, address, locality, zip, state, phone, website, categories] unless already_saved.key?(key)
      already_saved[key] = true
      # in the future we could extract the "where" and "what" keywords in the listings
    end

    CSV.open(@filename, 'a') do |f|
      results.each{|r| f << r}
    end
  end

  private 
  def extract_website(listing_node)
    website = listing_node.search('.track-visit-website')[0]
    website = website.attributes['href'].value.gsub('/business/site?link=','') if website
    CGI::unescape(website) if website   
  end
    
end

if __FILE__ == $0
  Search.new('results.csv').run
end
