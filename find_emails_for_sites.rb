#!/usr/bin/env ruby

require 'mechanize'
require 'csv'
require 'cgi'

class EmailsForSites
  def initialize(filename)
    data = CSV.read filename
    i = data.shift.index "website"
    @websites  = data.each.map{|e| e[i].strip if e[i] != nil && e[i].strip.length > 0 }.reject{ |e| e==nil}
    @outfile = "results_emails.csv"
    puts "will search #{@websites.length} websites"
    @agent = Mechanize.new
    @found, @searched = 0, 0
    @emails_found = {}
  end

  def run
    CSV.open(@outfile, 'w') {|csv| csv << %w(website, link_text1, email1, email2, etc)}
    @websites.each do |website|
      root_page = safely{@agent.get(website)}
      next if root_page == nil
      found_email = false
      find_candidate_pages(root_page).each do |page|
        found_email = true if spider(page)
      end      
      @found += 1 if found_email
      @searched += 1
      puts "\tfound emails in #{@found} of #{@searched} websites: #{(@found.to_f/@searched * 100).round}%"
    end
  end

  private
  def spider(page)
    safely do
      puts "searching #{page.uri}"
      links = find_emails(page)
      if links.length > 0
        save(page.uri.to_s, links)
      end
    end
  end

  def safely(&block)
    begin
      yield
    rescue Exception => e
      puts "Error: #{e}. Continuing."
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

  def save(url, emails)
    CSV.open(@outfile, 'a') do |csv|
      csv << [url] + emails
    end
  end
end

if __FILE__ == $0
  EmailsForSites.new('results.csv').run
end
