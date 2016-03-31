ruleset manage_fleet {
  meta {
    name "Manage_Fleet"
    description <<
Child Pico
>>
    author "Thomas Tingey"
    logging on
    sharing on

    use module  b507199x5 alias wrangler
    provides vehicles, children, trips, allSubs, vehicle_ecis, get_reports

  }
  global {
    get_reports = function() {
      trip_reports = ent:trip_reports || [];
      //Only returns five so figure out last index
      end_index = (trip_reports.length() > 4) => 4 | trip_reports.length() - 1;
      sliced_reports = (end_index > -1) => trip_reports.slice(end_index) | [];
      reversed_trips = sliced_reports.reverse();
      reversed_trips;
    }
    vehicles = function() {
      vehicles = allSubs();
      stripped_vehicles = vehicles.map(function(vehicle){
                vals = vehicle.values();
                vals.head();
      });
      filtered_subscriptions = stripped_vehicles.filter(function(obj) {
          obj{"status"} eq "subscribed" && obj{"relationship"} eq "Fleet" && obj{"name_space"} eq "Fleet_Subscriptions"
        });
      filtered_subscriptions;
    }

    vehicle_ecis = function() {
      vehicle_subs = vehicles();
      vehicle_ecis = vehicle_subs.map(function(vehicle_obj) {
        vehicle_obj{"attributes"}
      });

      vehicle_ecis.klog("Ecis: ")
    }

    allSubs = function() {
      wranglerSubs = wrangler:subscriptions();
      subscriptions = wranglerSubs{"subscriptions"};
      subscriptions{"subscribed"};
    }

    children = function() {
      wranglerChildren = wrangler:children();
      children = wranglerChildren{"children"};
      children;
    }

    trips = function() {
      theChildren = children();
      theTrips = theChildren.map(function(theChild){
          url = "https://cs.kobj.net/sky/cloud/";
          childEci = theChild[0];
          rid = "b507769x4.prod";
          funcCall = "trips";
          params = {};
          response = http:get("#{url}#{rid}/#{funcCall}", (params || {}).put(["_eci"], childEci));

          responseCode = response{"status_code"};

          error_info = {
                            "error": "sky cloud failed",
                            "httpStatus": {
                                "code": responseCode,
                                "message": response{"status_line"}
                            }
                        };

          response_content = response{"content"}.decode();
          response_error = (response_content.typeof() eq "hash" && response_content{"error"}) => response_content{"error"} | 0;
          response_error_str = (response_content.typeof() eq "hash" && response_content{"error_str"}) => response_content{"error_str"} | 0;
          error = error_info.put({"skyCloudError": response_error, "skyCloudErrorMsg": response_error_str, "skyCloudReturnValue": response_content});
          is_bad_response = (response_content.isnull() || response_content eq "null" || response_error || response_error_str);

          vehicle_final = {}
                          .put([childEci], response_content);


          //This sets theTrips either to the content or the error
          (responseCode eq "200" && not is_bad_response) => vehicle_final | error
          //childEci => response_content | error
        });
      theTrips;
    }

    get_back_channel_eci_by_eci = function(eci) {
      subs = vehicles();
      subscriptions = subs{"subscribed"};
      stripped_subs = subscriptions.map(function(subscription){
        vals = subscription.values();
        vals.head()
      });

      filtered_subs = stripped_subs.filter(function(obj) {
        obj{"attributes"} eq eci
      });

      back_channel = filtered_subs.map(function(obj) {
        obj{"back_channel"}
      });

      back_channel.head()
    }
  }

  rule create_vehicle {
    select when car new_vehicle
    pre {
      name = "Vehicle-" + ent:wtf.as(str);
      attributes = {}
                    .put(["Prototype_rids"],"b507769x6.prod;b507769x3.prod;b507769x4.prod") // semicolon separated rulesets the child needs installed at creation
                    .put(["name"], name) // name for child
                    .put(["parent_eci"],"A56C7E82-F55B-11E5-AA88-EF82E71C24E1")
                    ;

    }
    {
      event:send({"cid":meta:eci()}, "wrangler", "child_creation")  // wrangler os event.
      with attrs = attributes.klog("attributes: "); // needs a name attribute for child
    }
    always{
      set ent:wtf 0 if not ent:wtf;
      set ent:wtf ent:wtf + 1;
      log("create child for " + child);
    }
  }

    rule delete_vehicle {
        select when car unneeded_vehicle
            pre {
                eci = event:attr("eci").klog("delete this eci: ");
                attributes = {}
                            .put(["deletionTarget"], eci)
                            ;
                back_channel_eci = get_back_channel_eci_by_eci(eci);
                bc_attributes = {}
                                    .put(["eci"], back_channel_eci)
                                    ;
            }

            if (eci neq '') then {
                event:send({"cid":meta:eci()}, "wrangler", "child_deletion")
                    with attrs = attributes.klog("del attributes: ");
                event:send({"cid":meta:eci()}, "wrangler", "subscription_removal")
                    with attrs = bc_attributes.klog("bc_attributes: ");
            }

            always {
                log "can't delete an empty eci: " + eci;
            }
    }


    rule auto_accept {
      select when wrangler inbound_pending_subscription_added
      pre {
          attributes = event:attrs().klog("subcription :");
      }
      {
          noop();
      }
      always{
          raise wrangler event 'pending_subscription_approval'
          attributes attributes;
          log("auto accepted subcription.");
      }
    }

    rule generate_report {
      select when fleet generate_report
      pre {
        correlation_identifier = "Report-" + math:random(99999);
        the_ecis = vehicle_ecis();
        attrs = {}
                  .put(["correlation_identifier"], correlation_identifier)
                  .put(["vehicle_ecis"], the_ecis)
                  .klog("Attrs of get_report: ");
      }
      fired {
        raise explicit event 'start_scatter_report' attributes attrs;
      }
    }

    rule start_scatter_report {
      select when explicit start_scatter_report
      foreach event:attr("vehicle_ecis") setting (eci)
      pre {
        correlation_identifier = event:attr("correlation_identifier");
        tmp_reports = ent:running_reports || {};
        current_report = tmp_reports{[correlation_identifier]} || [];
        tmp_report = current_report.append(eci);
        running_reports = tmp_reports.put([correlation_identifier], tmp_report);
        attributes = {}
                      .put(["correlation_identifier"], correlation_identifier)
                      .put(["parent_eci"], meta:eci())
                      .put(["event_domain"], "vehicle")
                      .put(["event_identifier"], "recieve_report")
                      .klog("start_scatter_report attribs: ")
                      ;
      }
      {
        event:send({"cid":eci}, "fleet", "report_trips")
          with attrs = attributes.klog("Send report_trips event with attrs: ");
      }
      always {
        set ent:running_reports running_reports;
        log "Sent report trips to child: " + eci;
      }
    }

    rule recieve_report {
      select when vehicle recieve_report
      pre {
        results = ent:finished_reports || {};
        correlation_identifier = event:attr("correlation_identifier");
        temp_results = results{[correlation_identifier, event:attr("vehicle_eci")]} || [];
        vehicles_trips = event:attr("trips").decode().klog("Trips recieved from child eci: " + event:attr("vehicle_eci"));
        finished_trips = temp_results.append(vehicles_trips);
        results = results.put([correlation_identifier, event:attr("vehicle_eci")], finished_trips);

        temp_results = ent:running_reports || {};
        current_report = temp_results{[correlation_identifier]} || [];
        temp_report = current_report.filter(function(eci) {
            eci neq event:attr("vehicle_eci")
          });
        running_reports = temp_results.put([correlation_identifier], temp_report);
      }

      if (running_reports{[correlation_identifier]}.length() == 0) then {
        //We know it has all of the reports back
        send_directive("finished_cor_id") with
          finished_cor_id = "Cor Id : " + correlation_identifier + " has finished";
      }
      fired {
        raise explicit event 'finalize_report'
          attributes event:attrs();

          set ent:running_reports running_reports;
          set ent:finished_reports results;
          log("finished collecting");
      } else {
          set ent:running_reports running_reports;
          set ent:finished_reports results;
          log("Still waiting on reports");
      }
    }

    rule finalize_report {
      select when explicit finalize_report
      pre {
        attributes = event:attrs();
        correlation_identifier = event:attrs("correlation_identifier");
        finished_reports = ent:finished_reports;
        finalized_reports = ent:finalized_reports || [];
        //This is hacky way to make sure they are in the correct order found online
        reversed_finalized_reports = finalized_reports.reverse();
        trips = finished_reports{[correlation_identifier]}.values();
        count_of_trips = trips.length();
        count_of_vehicles = finished_reports.length();

        current_report = {}
                          .put(['responding'], count_of_trips)
                          .put(["vehicles"], count_of_vehicles)
                          .put(["trips"], trips)
                          .klog("The report: ");
        temp_reports = reversed_finalized_reports.append(current_report);
        final = temp_reports.reverse(); //Undo our hacky method
      }
      {
        send_directive("All is finished");
      }
      always {
        set ent:trip_reports final;
      }
    }

}