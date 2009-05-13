require 'erb'

module GCal
  class Event
    attr_accessor :title, :description, :location, :starts_at, :ends_at, 
      :transparent, :batch_id, :operation, :google_id, :edit_link

    class AttributeError < RuntimeError; end

    VALID_OPERATIONS = [:update, :insert, :delete, :query]

    BASE_ENTRY = REXML::Element.new("entry")
    BASE_ENTRY.add_attributes({ 
      "xmlns"     => 'http://www.w3.org/2005/Atom',
      "xmlns:gd"  => 'http://schemas.google.com/g/2005' })
    BASE_ENTRY.add_element "category", { 
      "scheme"  => 'http://schemas.google.com/g/2005#kind',
      "term"    => 'http://schemas.google.com/g/2005#event' }
    BASE_ENTRY.add_element "gd:eventStatus",
        {"value" => 'http://schemas.google.com/g/2005#event.confirmed' }

    def to_xml
      @xml = BASE_ENTRY.clone
      add_title
      add_content
      set_start_and_end_times
      set_location     
      set_transparency
      set_batch_id
      set_operation
      set_google_id
      set_edit_link
      @xml
    end

    private

    def add_title
      title = @xml.add_element "title", {"type" => "text"}
      title.text = ERB::Util.html_escape(@title)
    end
    
    def check_times
      if @starts_at > @ends_at
        raise AttributeError, "Start time must be before end time" 
      end
    end

    def generate_times
      if @ends_at.nil?
        start_time = @starts_at.strftime("%Y-%m-%d")
        end_time = nil
      else
        start_time = @starts_at.strftime("%Y-%m-%dT%H:%M:%S")
        end_time =   @ends_at.strftime("%Y-%m-%dT%H:%M:%S")
        #TODO: TIMEZONES?
      end
      [start_time, end_time]
    end

    def set_start_and_end_times
      check_times
      start_time, end_time = generate_times
      time_hash = {"startTime" => start_time}
      time_hash.merge!("endTime" => end_time) if end_time
      @xml.add_element "gd:when", time_hash
    end

    def add_content
      content = @xml.add_element "content", {"type" => "text"}
      content.text = ERB::Util.html_escape(@description)
    end

    def set_location     
      @xml.add_element "gd:where",
        {"valueString" => ERB::Util.html_escape(@location)}
    end

    def set_transparency
      transparency = @transparent ? 'transparent' : 'opaque'
      @xml.add_element "gd:transparency", {
        "value" => 'http://schemas.google.com/g/2005#event.' + transparency }
    end

    def set_batch_id
      batch_id = @xml.add_element("batch:id")
      batch_id.text = @batch_id
    end

    def set_operation
      @xml.add_element("batch:operation", {"type" => @operation.to_s})
    end

    def set_google_id
      if @google_id
        g_id = @xml.add_element "id"
        g_id.text = @google_id
      end
    end

    def set_edit_link
      if @edit_link
        @xml.add_element("link", { 
          "rel"   => "edit",
          "type"  => 'application/atom+xml',
          "href"  => @edit_link.to_s })
      end
    end

    def validate_operation(operation)
      unless VALID_OPERATIONS.include? operation
        raise AttributeError, "Invalid batch operation", caller
      end
      true 
    end
  end
end
