require 'net/http'
require 'net/https'
require 'uri'
require 'enumerator'
require File.join(File.dirname(__FILE__), 'net_redirector')

module GCal
  class CalendarInvalidError < RuntimeError; end
  class NoSetupError < RuntimeError; end
  class TokenRevoked < RuntimeError; end
  
  class Session
    MAX_BATCH_REQUEST_SIZE = 50
    VALID_BATCH_OPS = [:update, :insert, :delete, :query]
    SUCCESSFUL_BATCH_STATUSES = [200, 201]
    UNSUCCESSFUL_BATCH_STATUSES = [404, 500]
    INVALID_CALENDAR_STATUS = 403

    # For now, just create green calendars.
    # Only 21 select colors are valid for gcal.
    GCAL_COLOR = "#528800"

    attr_accessor :http

    # Create a new Session object
    def initialize(token) 
      @token = token
      @http = Net::HTTP.new('www.google.com', 80)
    end
    
    #return feed url for that calendar
    def add_calendar(calendar)
      xml_text = calendar.to_xml.to_s
      resp = NetRedirector::post(@http, OWNED_CALENDARS_PATH, xml_text, headers)
      calendar.process_add_response(resp)
    end

    def delete_calendar(calendar)
      begin  
        NetRedirector.delete(@http, calendar.edit_path, headers)
      rescue Net::HTTPServerException => e
        case e.response
        when Net::HTTPBadRequest
          return nil # Can't delete calendar; probably user's primary cal.
        else
          raise
        end
      end
    end

    # Returns an array of calendar hashes or false if we need a new auth token.
    def get_calendar_list(opts = {})
      feed_url = opts[:all_calendars] ? ALL_CALENDARS_PATH : OWNED_CALENDARS_PATH

      response = handle_calendar_list_request feed_url
      doc = REXML::Document.new(response.read_body)

      doc.elements.to_a("*/entry").collect{ |feed| Calendar.new feed }
    end
  
    #takes an array of hashes containing api call instructions
    #each hash should have the following:
    # :operation - :insert, :update or :delete
    # :event - the ExternalEvent object
    def batch_request(calls, feed_url = PRIVATE_CALENDARS_PATH)
      results = []
      calls.uniq.each_slice(MAX_BATCH_REQUEST_SIZE) do |call_set|
        batch_results = do_batch_request(call_set, feed_url)
        results += batch_results
      end
      results
    end

    private

    def headers
      { 'Content-Type'  => 'application/atom+xml',
        'Authorization' => %Q{AuthSub token="#{@token}"},
        'Connection'    => 'keep-alive' }
    end

    def do_batch_request(calls, feed_url)
      feed_url += '/batch'
      xml = batch_request_xml
      calls = get_fresh_edit_links(calls, feed_url)
      calls.each_with_index do |request, i|
        unless VALID_BATCH_OPS.include? request[:operation]
          raise ArgumentError, "Invalid batch operation", caller
        end
        entry = request[:event].to_xml
        batch_id = entry.add_element("batch:id")
        batch_id.text = i
        entry.add_element( "batch:operation",
                          {"type" => request[:operation].to_s})
        unless request[:operation] == :insert
          id = entry.add_element "id"
          id.text = request[:event].google_id
        end
        case request[:operation]
        when :update, :delete
          entry.add_element(  "link",
                          { "rel" => "edit",
                            "type" => 'application/atom+xml',
                            "href" => request[:edit_link].to_s
                          })
        end
        xml.add_element entry
      end
      resp = NetRedirector::post(@http, feed_url, xml.to_s, headers)
      case resp
      when Net::HTTPSuccess
        doc = REXML::Document.new resp.read_body
        return parse_batch_feed(doc, calls, xml.to_s)
      else
        raise GCal::Error, "Could not complete batch request!  Are you properly authenticated?"
      end
    end

    # takes an array of api call instructions and adds valid edit links based on
    # google event IDs
    def get_fresh_edit_links(calls, feed_url)
      xml = batch_request_xml
      # build batch request for all deletes/updates
      calls.each_with_index do |request, i|
        next if request[:operation] == :insert
        entry = xml.add_element("entry")
        id = entry.add_element "id"
        id.text = request[:event].google_id
        batch = entry.add_element("batch:id")
        batch.text = i
        entry.add_element("batch:operation", {"type" => "query"})
      end

      resp = NetRedirector::post(@http, feed_url, xml.to_s, headers)
      case resp
      when Net::HTTPSuccess
        doc = REXML::Document.new resp.read_body
        # get edit links from the api calls and append them to the instruction
        doc.root.elements.each("atom:entry") do |e|
          index = e.elements["batch:id"].text.to_i
          edit_tag = e.elements.detect do |el|
            el.name == 'link' and el.attributes['rel']=='edit'
          end
          # If we get no edit link, use the google event ID.  parse_batch_feed
          # will give more useful info than raising an error here.
          link = edit_tag.nil? ?  e.elements['atom:id'].text :
            edit_tag.attributes['href']
          calls[index].merge! :edit_link => link
        end
      else
        raise GCal::Error, "Could not get edit links!"
      end

      calls
    end

    def parse_batch_feed(xml_feed, calls, original_xml_string)
      entries = xml_feed.elements['atom:feed'].elements.select{|e|e.name == 'entry'}
      # Go through each batch operation and note whether it failed.  If it's an
      # insert, tack on the :google_id to the event.
      entries.each do |e|
        if e.elements["batch:interrupted"]
          raise GCal::Error,  "Batch request interrupted! \n#{e.to_s}\n\n" +
                              "Request XML:\n #{original_xml_string}"
        end
        index = e.elements["batch:id"].text.to_i
        status = e.elements["batch:status"].attributes["code"].to_i
        raise GCal::CalendarInvalidError if status == INVALID_CALENDAR_STATUS
        pass = SUCCESSFUL_BATCH_STATUSES.include?(status)
        request = calls[index]
        request.merge! :pass => pass
        if request[:operation] == :insert and pass
          request[:event].google_id = e.elements['atom:id'].text
        end
        if e.elements["gd:when"]
          request.merge!({
              :starts_at => e.elements["gd:when"].attributes["startTime"],
              :ends_at => e.elements["gd:when"].attributes["endTime"]})
        end
      end

      calls
    end
    
    def handle_calendar_list_request(feed_url)
      NetRedirector::get(@http, feed_url, headers)
    rescue Net::HTTPServerException => e
      case e.response
      when Net::HTTPForbidden
        raise GCal::NoSetupError
      when Net::HTTPUnauthorized
        raise GCal::TokenRevoked
      else
        raise
      end
    end

    def batch_request_xml
      xml = REXML::Element.new("feed")
      xml.add_attributes({  "xmlns" => 'http://www.w3.org/2005/Atom',
                            "xmlns:batch" => 'http://schemas.google.com/gdata/batch',
                            "xmlns:gCal" => 'http://schemas.google.com/gCal/2005'})
      xml
    end
  end
end


