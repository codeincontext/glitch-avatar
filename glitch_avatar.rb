#!/usr/bin/env ruby

# This script glitches an image file, and performs an OAuth POST to
# http://twitter.com/account/update_profile_image.json
#
# The glitch bit is just from my trial and error.
# The OAuth bit from https://gist.github.com/hayesdavis/97756

require 'rubygems'
require 'oauth'
require 'open-uri'
require 'net/http'
require 'yaml'
require 'cgi'

CRLF = "\r\n"
INPUT_FILE = 'input.jpg'
OUTPUT_FILE = 'output.jpg' 


begin
  oauth_config = YAML.load(IO.read('oauth.yml'))
  #Make sure oauth_config contains symbol keys
  oauth_config.replace(oauth_config.inject({}) {|h, (key,value)| h[key.to_sym] = value; h})
rescue
  puts "You must have an oauth.yml file with consumer_key, consumer_secret, token & token_secret"
end

#Quick and dirty method for determining mime type of uploaded file
def mime_type(file)
  case 
    when file =~ /\.jpg/ then 'image/jpg'
    when file =~ /\.gif$/ then 'image/gif'
    when file =~ /\.png$/ then 'image/png'
    else 'application/octet-stream'
  end
end

#Encodes the request as multipart
def add_multipart_data(req,params)
  boundary = Time.now.to_i.to_s(16)
  req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
  body = ""
  params.each do |key,value|
    esc_key = CGI.escape(key.to_s)
    body << "--#{boundary}#{CRLF}"
    if value.respond_to?(:read)
      body << "Content-Disposition: form-data; name=\"#{esc_key}\"; filename=\"#{File.basename(value.path)}\"#{CRLF}"
      body << "Content-Type: #{mime_type(value.path)}#{CRLF*2}"
      body << value.read
    else
      body << "Content-Disposition: form-data; name=\"#{esc_key}\"#{CRLF*2}#{value}"
    end
    body << CRLF
  end
  body << "--#{boundary}--#{CRLF*2}"
  req.body = body
  req["Content-Length"] = req.body.size
end

#Uses the OAuth gem to add the signed Authorization header
def add_oauth(req,auth)
  consumer = OAuth::Consumer.new(
    auth[:consumer_key],
    auth[:consumer_secret],
    {:site=>'https://api.twitter.com/1.1'}
  )
  access_token = OAuth::AccessToken.new(consumer,auth[:token],auth[:token_secret])
  consumer.sign!(req,access_token)
end

# Set a random byte in the line to 0
def mutate_line(line)
  line[rand(line.length-1)] = "0"
end

# Copy a file from INPUT_FILE to OUTPUT_FILE, mutating random lines
def mutate_file
  File.open(INPUT_FILE,'r') do |input|
    File.open(OUTPUT_FILE,'w') do |output|
      while line = input.gets
        mutate_line line if rand(15) == 0
        output.puts(line)
      end
    end
  end
end


mutate_file
image_file = File.new(OUTPUT_FILE)

#Actually do the request and print out the response
url = URI.parse('https://api.twitter.com/1.1/account/update_profile_image.json')

http = Net::HTTP.new(url.host, url.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE # note: DANGEROUS

req = Net::HTTP::Post.new(url.request_uri)
add_multipart_data(req,:image=>image_file)
add_oauth(req,oauth_config)
res = http.request(req)
puts res.body
