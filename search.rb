#!/usr/bin/env ruby

require 'mechanize'
require 'csv'
require 'cgi'
require File.join(File.dirname(__FILE__), 'find_emails_for_sites.rb')

class Search

  def initialize(filename)
    @terms = %w(Dock+Builders Marina Boat+Dock Dock+Pilings Marine+Contractor Yacht+Club Boat+Lift)
#    @states = %w(AL AK AZ AR CA CO CT DE DC FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY)
    @states = %w(FL)
    @filename = filename
    @email_finder = FindEmailsForSites.new
  end

  def run
    puts "Extracting data, saving to " + @filename
    CSV.open(@filename, 'w') {|f| f << %w(state_searched_with first_search_term company_name neighborhood address locality zip state phone website categories email1 email2 email3 email4) }
    @states.each do |state|
      agent = Mechanize.new
      already_saved = {}
      @terms.each do |term|
        url = "http://www.yellowpages.com/fl/boat-dock?g=#{state}&q=#{term}"
        page = safely{agent.get(url)}
        if page == nil
          next
          puts "error fetching #{url}, continuing silently"
        end
        search(page, already_saved, state, term)
      end
    end
  end

  def search(page, already_saved, state, term)
    begin      
      extract(page, already_saved, state, term)
      next_link = page.links.find { |l| l.text == 'Next' }
      puts "Extracting #{state} #{term} " + next_link.attributes['href'].match('.*(page=\d+).*')[1] if next_link
    end while next_link && page = safely{next_link.click}
  end
  
  def extract(page, already_saved, state_searched_with, first_search_term)  
    page.search('.listing_content').each do |l|
      company_name = l.search('.business-name').text.strip
      address = l.search('.street-address').text.strip
      key = "#{company_name}_#{address}"
      next if already_saved.key?(key)
      neighborhood = l.search('.business-neighborhoods').text.strip.gsub(/[\r\n]+/,'')
      categories = l.search('.business-categories').text.strip.gsub(/[\r\n]+/,'')
      locality = l.search('.locality').text.strip
      zip = l.search('.postal-code').text.strip
      state = l.search('.region').text.strip
      phone = l.search('.business-phone').text.strip
      website = extract_website(l)
      emails = @email_finder.spider_site_for_emails(website)
      CSV.open(@filename, 'a') do |csv|
        csv << [state_searched_with, first_search_term, company_name, neighborhood, address, locality, zip, state, phone, website, categories] + emails
      end
      already_saved[key] = true
      # in the future we could extract the "where" and "what" keywords in the listings
    end
  end

  private 
  def extract_website(listing_node)
    website = listing_node.search('.track-visit-website')[0]
    website = website.attributes['href'].value.gsub('/business/site?link=','') if website
    CGI::unescape(website) if website   
  end
    

  # TODO extract into a module and mix in
  def safely(&block)
    begin
      yield
    rescue Exception => e
      if e.message =~ /connection was aborted/
        begin
          yield 
        rescue Exception => e
          puts "Error on retry: #{e}. Continuing."
        end
      else
        puts "Error: #{e}. Continuing."
      end
    end
  end

end

if __FILE__ == $0
  Search.new('results.csv').run
end
