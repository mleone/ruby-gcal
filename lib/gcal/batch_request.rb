module GCal
  class BatchRequest
  
    class AttributeError < RuntimeError; end
    
    BASE_ENTRY = REXML::Element.new("feed")
    BASE_ENTRY.add_attributes({   
      "xmlns"       => 'http://www.w3.org/2005/Atom',
      "xmlns:batch" => 'http://schemas.google.com/gdata/batch',
      "xmlns:gCal"  => 'http://schemas.google.com/gCal/2005'})

    def initialize
      @xml = BASE_ENTRY.clone
    end

    def to_xml
      @xml
    end

    def add_entry(gcal_event, operation, uid)
      gcal_event.batch_id = uid
      gcal_event.operation = operation
      @xml.add_element gcal_event.to_xml
      true
    end

    private
  end
end
