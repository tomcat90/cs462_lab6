ruleset trip_store {
  meta {
    name "Trip_Store"
    description <<
For a lab I have to write
>>
    author "Thomas Tingey"
    logging on
    sharing on
  }

  rule collect_trips {
      select when explicit trip_processed mileage "(.*)" setting(mileage)
      pre {
        now = time:now();
      }
      fired {
        log("Trips before: " + ent:trips);
        set ent:trips{now} mileage;
        log("Trips after: " + ent:trips);
      }

  }

  rule clear_trips  {
    select when car trip_reset
    always{
      //Clears the trips by setting them to empty
      set ent:trips [];
      set ent:long_trips [];
    }
  }
}