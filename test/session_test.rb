require 'test/unit'
require 'yaml'
require File.dirname(__FILE__) + '/../lib/gcal'

class SessionTest < Test::Unit::TestCase
  
  CONFIG = YAML.load_file(
    File.join(File.dirname(__FILE__), "calendar_tokens.yml"))

  def setup
    @sess = GCal::Session.new CONFIG[:normal_account_token]
    @no_gcal_setup_sess = GCal::Session.new CONFIG[:no_setup_account_token]
  end

  def test_get_calendar_list
    list = @sess.get_calendar_list
    assert !list.empty?
    list.each do |cal|
      assert cal.edit_path.is_a?(String)
      assert cal.path.is_a?(String)
    end
  end

  def test_get_session_token_with_bad_token
    assert_raise(GCal::TokenInvalidError){GCal.get_session_token("not_real")}
  end
  
  def test_get_calendar_list_with_no_gcal_setup
    assert_raise(GCal::NoSetupError){@no_gcal_setup_sess.get_calendar_list}
  end  
  
  def test_batch_request_with_invalid_calendar
    fake_path = '/calendar/feeds/f1ko4%40group.calendar.google.com/private/full'
    requests = [make_request(generate_events(1).first, :insert)]
    assert_raise(GCal::CalendarInvalidError) do
      @sess.batch_request(requests, fake_path)
    end
  end

  def test_add_and_delete_calendar
    calendar_title = "Unit Test: #{Time.now.to_s}"
    cal = GCal::Calendar.new

    cal.title = calendar_title
    cal.summary = "A great unit test calendar."
    cal.time_zone = "America/New_York"

    assert_kind_of String, @sess.add_calendar(cal)

    list = @sess.get_calendar_list
    returned_cal = list.detect do |cal| 
      cal.title == calendar_title
    end

    assert_equal returned_cal.title, calendar_title
    assert_equal returned_cal.summary, "A great unit test calendar."

    # delete the new calendar:
    assert_nothing_raised do
      @sess.delete_calendar returned_cal
    end

    assert @sess.get_calendar_list.length < list.length
  end


  def test_insert_event
    gcal_event = generate_events(1).first
    request = [make_request(gcal_event, :insert)]
    result = @sess.batch_request(request)
    assert result.first[:pass]
   
    returned_event = result.first[:event] 
    request = [make_request(returned_event, :update)]
    result = @sess.batch_request(request)
    assert result.first[:pass]
    
    returned_event = result.first[:event] 
    request = [make_request(returned_event, :delete)]
    result = @sess.batch_request(request)
    assert result.first[:pass]
  end

  def test_batch_request
    requests = []

    test_events = generate_events(10)
    
    test_events.each{|e| requests << make_request(e, :insert) }
    results = []
    assert_nothing_raised{results = @sess.batch_request(requests)}
    assert results.all?{ |req| req[:pass] }

    # update the events:
    requests = []
    test_events.each{|e|requests << make_request(e, :update)}
    assert_nothing_raised{results = @sess.batch_request(requests)}
    assert results.all?{ |req| req[:pass] }
    
    # delete the events:
    requests = []
    test_events.each{|e|requests << make_request(e, :delete)}
    assert_nothing_raised{results = @sess.batch_request(requests)}
    assert results.all?{ |req| req[:pass] }

    #ensure that we fail when attempting to delete these events again.
    requests = []
    test_events.each{|e|requests << make_request(e, :delete)}
    assert_nothing_raised{results = @sess.batch_request(requests)}
    assert !results.any?{ |req| req[:pass] }
  end

  private 

  def make_request(event, kind)
    { :event => event, :operation => kind }
  end

  def generate_events(num_events)
    (1..num_events).map do |uid| 
      event = GCal::Event.new
      event.title = "party #{uid}!"
      event.description = "fun times"
      event.location = "right over here"
      event.starts_at = Time.now
      event.ends_at = Time.now + (10_000 * uid) 
      event.transparent = false
      event
    end
  end
end

