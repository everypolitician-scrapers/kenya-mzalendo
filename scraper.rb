#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'json'
require 'date'

require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def date_from(str)
  return if str.to_s.empty?
  return str if str[/^(\d{4})$/]
  Date.parse(str).to_s
end

def scrape_list(url)
  puts url
  noko = noko_for(url)
  noko.css('.position-listing a[href*="/person/"]/@href').each do |p|
    scrape_person(URI.join url, p.text)
  end
  next_page = noko.css('.pagination a.next/@href').text
  scrape_list(URI.join url, next_page) unless next_page.empty?
end

def scrape_person(url)
  noko = noko_for(url)

  sidebar = noko.css('div.constituency-party')
  area = sidebar.at_xpath('.//a[contains(@href,"/place/")]')

  party_node = sidebar.xpath('.//a[contains(@href,"/organisation/")]').find { |n|
    org_url = URI.join(url, n.attr('href')).to_s
    noko_org = noko_for(org_url)
    type = noko_org.css('div.object-titles p').text == 'Political Party'
  }
  party_info = party_node ? party_node.text.strip : 'Independent (IND)'
  party, party_id = party_info.match(/(.*) \((.*)\)/).captures rescue party, party_id = [party_info, nil]

  contacts = noko.css('.contact-details')

  alt_name = contacts.xpath('.//h3[contains(.,"Full name")]/following-sibling::p[1]').text rescue nil

  data = {
    id: url.to_s[/person\/(.*)\//, 1],
    name: noko.css('div.object-titles h1').text.gsub(/[[:space:]]+/, ' ').strip,
    party: party,
    party_id: party_id,
    area: area ? area.text.strip : '',
    email: contacts.css('a[href*="mailto:"]/@href').map(&:text).first.to_s.sub('mailto:',''),
    birth_date: date_from(contacts.xpath('.//h3[contains(.,"Born")]/following-sibling::p[1]').text),
    facebook: contacts.css('a[href*="facebook"]/@href').map(&:text).first.to_s,
    twitter: contacts.css('a[href*="twitter"]/@href').map(&:text).first.to_s,
    term: '11',
    image: noko.css('.profile-pic img/@src').text,
    source: url.to_s,
    identifier__mzalendo: noko.at_css('meta[name="pombola-person-id"]/@content').text,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  data[:alternate_names] = alt_name unless alt_name.to_s.empty?
  ScraperWiki.save_sqlite([:name, :term], data)
end

term = {
  id: '11',
  name: '11th Parliament',
  start_date: '2013-03-28',
  source: 'https://en.wikipedia.org/wiki/11th_Parliament_of_Kenya',
}
ScraperWiki.save_sqlite([:id], term, 'terms')

scrape_list('http://info.mzalendo.com/position/member-national-assembly/')
