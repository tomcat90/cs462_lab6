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
  }

  rule collect_trips {
      select when explicit trip_processed
      pre {
        now = time:now();
        mileage = event:attr("mileage");
        newTrip = {"timestamp" : time, "length": mileage};
      }
      fired {
        set ent:trips ent:trips.append(newTrip);
        raise explicit event 'log_trips';
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
}