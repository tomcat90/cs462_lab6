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
  rule process_trip {
    select when car new_trip
    pre{
      mileage = event:attr("mileage");
    }
    {
      send_directive("trip") with
        trip_length = "#{mileage}";
    }
  }

}