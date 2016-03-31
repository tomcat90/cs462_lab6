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

    short_trips = function() {
      AllTrips = trips().klog("ALL TRIPS: ");
      trips().filter(function(x) {
        long_trips().none(function(y) {
          (x{"timestamp"}.klog("x: ") eq y{"timestamp"}.klog("y: ")).klog("x eq y?: ");
        }).klog("x in long?: ");
      }).klog("Short trips: ");
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

  rule report_trips {
    select when fleet report_trips
    pre {
      my_trips = trips();
      my_trips_map = {}
                      .put(["the_trips"], my_trips);

      attributes = {}
                    .put(["correlation_identifier"], event:attr("correlation_identifier"))
                    .put(["trips"], my_trips_map.encode())
                    .put(["vehicle_eci"], meta:eci())
                    .klog("These are what the child is sending: ");
      parent_eci = event:attr("parent_eci").klog("Sending to: ");
      parent_event_domain = event:attr("event_domain").klog("with this domain: ");
      parent_event_identifier = event:attr("event_identifier").klog("And this id: ");
    }
    {
      event:send({"cid":parent_eci}, parent_event_domain, parent_event_identifier)
          with attrs = attributes;
    }
  }
}