module GCal
  class BatchRequest
    class AttributeError < RuntimeError; end

    BASE_ENTRY = REXML::Element.new("feed")
    BASE_ENTRY.add_attributes({   
      "xmlns"       => 'http://www.w3.org/2005/Atom',
      "xmlns:batch" => 'http://schemas.google.com/gdata/batch',
      "xmlns:gCal"  => 'http://schemas.google.com/gCal/2005'})

    def to_xml
      @xml = BASE_ENTRY.clone
      @xml
    end

    private
  end
end
