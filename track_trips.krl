ruleset track_trips {
  meta {
    name "Track_Trips"
    description <<
For a lab I have to write
>>
    author "Thomas Tingey"
    logging on
    sharing on
    provides process_trip

  }
  rule process_trip {
    select when echo message
    pre{
      mileage = event:attr("mileage");
    }
    {
      send_directive("trip") with
        trip_length = "#{mileage}";
    }
  }

}