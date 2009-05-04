module NetRedirector
  class Error < RuntimeError; end

  def self.request_with_redirects(http, method, path, payload, headers, limit = 10)
    raise NetRedirector::Error, 'HTTP redirect too deep' if limit == 0

    response = http.send_request(method, path, payload, headers)
    case response
    when Net::HTTPSuccess     then response
    when Net::HTTPRedirection then request_with_redirects(http,
                                                          method, 
                                                          response['location'],
                                                          payload,
                                                          headers,
                                                          limit - 1)
    else
      response.error!
    end
  end

  def self.post(http, path, payload, headers)
    NetRedirector::request_with_redirects(http, 'POST', path, payload, headers)
  end

  def self.put(http, path, payload, headers)
    NetRedirector::request_with_redirects(http, 'PUT', path, payload, headers)
  end

  def self.get(http, path, headers)
    NetRedirector::request_with_redirects(http, 'GET', path, '', headers)
  end

  def self.delete(http, path, headers)
    NetRedirector::request_with_redirects(http, 'DELETE', path, '', headers)
  end
end