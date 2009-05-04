require 'erb'

module GCal
  class Event
    attr_accessor :title, :description, :location, :starts_at, :ends_at, 
      :transparent, :google_id

    class AttributeError < RuntimeError; end

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
  end
end
