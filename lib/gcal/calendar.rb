module GCal
  class Calendar
    attr_accessor :title, :time_zone, :summary, :path, :edit_path

    # For now, just create green calendars.  Only 21 select colors are valid.
    COLOR = "#528800"

    BASE_ENTRY = REXML::Element.new("entry")
    BASE_ENTRY.add_attributes({
      "xmlns"       => 'http://www.w3.org/2005/Atom',
      "xmlns:gd"    => 'http://schemas.google.com/g/2005',
      "xmlns:gCal"  => 'http://schemas.google.com/gCal/2005'})
    
    def initialize(xml_element=nil)
      generate_from_xml! xml_element
    end

    def generate_from_xml!(xml_element)
      if @xml = xml_element
        @title      = extract_title
        @summary    = extract_summary
        @path       = extract_path
        @edit_path  = extract_edit_path
        @time_zone  = extract_time_zone
      end 
    end

    def to_xml
      @xml = BASE_ENTRY.clone
      generate_title
      generate_summary
      generate_time_zone
      generate_color
      @xml
    end

    # processes Net::HTTP response from request to add a new gcal.
    def process_add_response(resp)
      case resp
        when Net::HTTPSuccess
          entry = REXML::Document.new(resp.read_body).elements["entry"]
          self.generate_from_xml! entry
          @path
        else
          raise GCal::Error, "Couldn't add calendar!  Are you authenticated?"
      end
    end

    private

    def generate_title
      title = @xml.add_element( "title", { "type" => "text" })
      title.text = @title
    end

    def generate_summary
      summary = @xml.add_element( "summary", { "type" => "text" })
      summary.text = @summary || "No summary"
    end
    
    def generate_time_zone
      timezone = @xml.add_element( "gCal:timezone", { "value" => time_zone })
      timezone.text = ''
    end
    
    def generate_color
      color = @xml.add_element( "gCal:color", { "value" => COLOR })
      color.text = ''
    end
    
    def extract_title
      @xml.elements["title"].text
    end
    
    def extract_summary
      summary = @xml.elements["summary"]
      summary.text  if summary
    end
    
    def extract_path
      URI.parse(@xml.elements["link"].attributes["href"]).path
    end
    
    def extract_time_zone
      @xml.elements["gCal:timezone"].attributes["value"]
    end

    def extract_edit_path
      edit_element = @xml.elements.to_a("./link").detect do |link|
          link.attributes["rel"] == "edit"
      end
      URI.parse(edit_element.attributes["href"]).path
    end
  end
end
