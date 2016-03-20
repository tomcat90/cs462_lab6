ruleset trip_store {
  meta {
    name "Trip_Store"
    description <<
For a lab I have to write
>>
    author "Thomas Tingey"
    logging on
    sharing on
    provides trips, long_trips, short_trips

  }

  global {
    trips = function() {
      ent:trips;
    };

    long_trips = function() {
      ent:long_trips;
    };
  }

  rule collect_trips {
      select when explicit trip_processed
      pre {
        now = time:now();
        mileage = event:attr("mileage");
        newTrip = {"timestamp" : now, "length": mileage};
      }
      fired {
        set ent:trips ent:trips.append(newTrip);
        raise explicit event 'log_trips';
      }
  }

  rule collect_long_trips {
      select when explicit found_long_trip
      pre {
        now = time:now();
        mileage = event:attr("mileage").klog("mileage is: ");
        newTrip = {"timestamp" : now, "length": mileage};
      }
      fired {
        set ent:long_trips ent:long_trips.append(newTrip);
        raise explicit event 'log_long_trips';
      }
  }


  rule clear_trips  {
    select when car trip_reset
    always{
      clear ent:trips;
      clear ent:long_trips;
    }
  }

  rule log_trips {
    select when explicit log_trips
    send_directive("trips") with
      trips = ent:trips;
  }

  rule log_long_trips {
    select when explicit log_long_trips
    send_directive("long_trips") with
      long_trips = ent:long_trips;
  }
}