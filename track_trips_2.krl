ruleset track_trips_2 {
  meta {
    name "Track_Trips_2"
    description <<
For a lab I have to write
>>
    author "Thomas Tingey"
    logging on
    sharing on
    provides process_trip

  }
  global {
    long_trip = 100
  }
  rule process_trip {
    select when car new_trip
    pre{
      mileage = event:attr("mileage");
    }
    send_directive("trip") with
      trip_length = "#{mileage}";
    fired {
      raise explicit event 'trip_processed' attributes event:attrs();
    }
  }

  rule find_long_trips {
    select when explicit trip_processed
    pre{
      mileage = event:attrs('mileage').klog("Mileage is: ");
      attrs = event:attrs().klog("attributes are : ");
    }
    if (10000 > long_trip) then {
      log ("It's a long trip");
    }
    fired{
      raise explicit event 'found_long_trip'
    }
  }
}