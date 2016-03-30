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
    provides vehicles, children, trips

  }
  global {
    vehicles = function() {
      wranglerSubs = wrangler:subscriptions();
      subscriptions = wranglerSubs{"subscriptions"};
      subscriptions;
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
                          .put([childEci], response_content[0]);


          //This sets theTrips either to the content or the error
          (responseCode eq "200" && not is_bad_response) => vehicle_final | error
          //childEci => response_content | error
        });
      theTrips;
    }

    get_back_channel_eci_by_name = function(name) {
      subs = vehicles();
      subscriptions = subs{"subscribed"};
      stripped_subs = subscriptions.map(function(subscription){
        vals = subscription.values();
        vals.head()
      });

      filtered_subs = stripped_subs.filter(function(obj) {
        obj{"subscription_name"} eq name
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
                name = event:attr("name").klog("delete this subName: ");
                attributes = {}
                            .put(["deletionTarget"], eci)
                            ;
                back_channel_eci = get_back_channel_eci_by_name(name);
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
}