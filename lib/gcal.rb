module GCal
 
  require 'rexml/document'
  
  # require select libs from the gcal directory 
  LIBS = %w(event calendar session batch_request).freeze
  LIBS.each{|lib| require File.join(File.dirname(__FILE__), "gcal/#{lib}")}
  
  HOME_URL = 'http://calendar.google.com'

  BASE_PATH = '/calendar/feeds/default/'
  OWNED_CALENDARS_PATH = "#{BASE_PATH}owncalendars/full"
  PRIVATE_CALENDARS_PATH = "#{BASE_PATH}private/full"
  ALL_CALENDARS_PATH = "#{BASE_PATH}allcalendars/full"

  class Error < RuntimeError; end
  class TokenInvalidError < RuntimeError; end

  class << self
    def get_session_token(auth_token)
      https = Net::HTTP.new('www.google.com', 443)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      location = '/accounts/AuthSubSessionToken'
      resp = https.get location, generate_auth_headers(auth_token)
      case resp
        when Net::HTTPOK
          stoken = resp.read_body.split("=").last.strip
          return stoken
        when Net::HTTPForbidden
          raise GCal::TokenInvalidError
        else
          raise GCal::Error, "Error getting session token:\n #{resp.read_body}"
      end
    end

    private

    def generate_auth_headers(token)
      { 'Content-type'  => 'application/x-www-form-urlencoded',
        'Authorization' => %Q{AuthSub token="#{token}"} }
    end
  end 
 
end

