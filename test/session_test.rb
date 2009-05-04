require 'test/unit'
require File.dirname(__FILE__) + '/../lib/gcal'

class SessionTest < Test::Unit::TestCase
  
  # generate 10 unique gcal events:
  EVENTS = (1..10).map do |uid| 
    event = GCal::Event.new
    event.title = "party #{uid}!"
    event.description = "fun times"
    event.location = "right over here"
    event.starts_at = Time.now
    event.ends_at = Time.now + (10_000 * uid) 
    event.transparent = false
    event
  end


  # TO MAKE TESTS PASS, ADD TOKENS HERE.
  # For @sess, use a valid auth token from a Google account with Google Calendar
  # set up.
  # For @no_gcal_setup_sess, use a valid auth token from a Google account
  # which has never been logged into the Google Calendar app.
  def setup
    @sess = GCal::Session.new("")
    @no_gcal_setup_sess = GCal::Session.new("")
  end

  def test_get_calendar_list
    list = @sess.get_calendar_list.map{|feed|feed.class}.uniq
    assert(list.length == 1 && list.first == Hash)
  end

  def test_get_session_token_with_bad_token
    assert_raise(GCal::TokenInvalidError){GCal.get_session_token("not_real")}
  end
  
  def test_get_calendar_list_with_no_gcal_setup
    assert_raise(GCal::NoSetupError){@no_gcal_setup_sess.get_calendar_list}
  end  
  
  def test_batch_request_with_invalid_calendar
    fake_path = '/calendar/feeds/f1ko4%40group.calendar.google.com/private/full'
    requests = [make_request(EVENTS.first, :insert)]
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
    list_length_after_add = list.length
    sleep 0.2 # ensure gdata lag doesn't cause the following test to fail.

    assert list.any?{ |cal| cal[:title] == calendar_title }

    # delete all calendars:
    assert_nothing_raised do
      list.each{|cal|@sess.delete_calendar(cal[:edit])}
    end

    assert @sess.get_calendar_list.length < list_length_after_add
  end


  def test_insert_event
    gcal_event = EVENTS.first
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

    # add ten events:
    EVENTS.each{|e| requests << make_request(e, :insert) }
    results = []
    assert_nothing_raised{results = @sess.batch_request(requests)}
    assert results.all?{ |req| req[:pass] }

    # update the events:
    requests = []
    EVENTS.each{|e|requests << make_request(e, :update)}
    assert_nothing_raised{results = @sess.batch_request(requests)}
    assert results.all?{ |req| req[:pass] }
    
    # delete the events:
    requests = []
    EVENTS.each{|e|requests << make_request(e, :delete)}
    assert_nothing_raised{results = @sess.batch_request(requests)}
    assert results.all?{ |req| req[:pass] }

    #ensure that we fail when attempting to delete these events again.
    requests = []
    EVENTS.each{|e|requests << make_request(e, :delete)}
    assert_nothing_raised{results = @sess.batch_request(requests)}
    assert !results.any?{ |req| req[:pass] }
  end

  private 

  def make_request(event, kind)
    { :event => event, :operation => kind }
  end

end
