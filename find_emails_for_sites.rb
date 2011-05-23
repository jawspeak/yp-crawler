#!/usr/bin/env ruby

require 'mechanize'
require 'csv'
require 'cgi'

class FindEmailsForSites
  def initialize
    @agent = Mechanize.new
    @found_in, @searched_in = 0, 0
    @emails_found = {}
  end

  # standalone entrypoint for getting all the results in the existing csv  search.rb
  def spider_csv_results(filename)
    data = CSV.read filename
    i = data.shift.index "website"
    @websites  = data.each.map{|e| e[i].strip if e[i] != nil && e[i].strip.length > 0 }.reject{ |e| e==nil}
    @outfile = "results_emails.csv"
    puts "will search #{@websites.length} websites"
    CSV.open(@outfile, 'w') {|csv| csv << %w(website email1 email2 email3 email4)}
    @websites.each do |website|
      all_pages_found = spider_site(website)
      if !all_pages_found.empty?
        @found_in += 1
        all_pages_found.each {|p| save(p)}
      end
      @searched_in += 1
      puts "\tfound emails in #{@found_in} of #{@searched_in} websites: #{(@found_in.to_f/@searched_in * 100).round}%"
    end
  end

  # find results for one url, used while creating one csv with everything in search.rb 
  # (this does omit the page we found the search on)
  # returns a max of 3
  def spider_site_for_emails(website)
    emails = spider_site(website).values.flatten
    emails[4] = nil
    emails.slice(0, 3)
  end

  private

  def spider_site(website)
    all_pages_found = {}
    return all_pages_found if website == nil || website.empty?
    root_page = safely{@agent.get(website)}
    return all_pages_found if root_page == nil
    find_candidate_pages(root_page).each do |page|
      spider(page, all_pages_found)
    end
    all_pages_found
  end
 
  def spider(page, all_pages_found)
    safely do
      puts " [email finder searching] #{page.uri}"
      email_links = find_emails(page)
      if email_links.length > 0
        all_pages_found[page.uri.to_s] = email_links
      end
    end
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

  LINKS_TO_CRAWL = /(contact)|(about)/i
  def find_candidate_pages(page) 
    pages = {}
    page.links.find_all{|l|l.text.match(LINKS_TO_CRAWL)}.each do |found|
      pages[found.uri.to_s] = found # remove dup links
    end
    to_crawl = [page]
    pages.values.each do |found|
      p = safely{@agent.click(found)}
      to_crawl << p if p != nil
    end
    to_crawl
  end
  
  def find_emails(page)
    found = page.links.find_all{|l|l.href.match(/mailto.*@/) if l.href}.map{|e| e.href.gsub('mailto:','').strip}.uniq
    found.reject!{|e| @emails_found.key? e}
    found.each {|e| @emails_found[e] = true}
    found
  end

  def save(pair)
    url, emails = pair
    CSV.open(@outfile, 'a') do |csv|
      csv << [url] + emails
    end
  end
end

if __FILE__ == $0
  FindEmailsForSites.new.spider_csv_results('results.csv')
end
