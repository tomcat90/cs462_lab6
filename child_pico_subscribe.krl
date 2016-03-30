ruleset child_pico_subscribe {
  meta {
    name "Child Pico Subscription"
    description <<
Child Pico Subscribing to parent
>>
    author "Thomas Tingey"
    logging on
    sharing on

    use module  b507199x5 alias wrangler

  }

rule childToParent {
    select when wrangler init_events
    pre {
       // find parant
       // place  "use module  b507199x5 alias wrangler_api" in meta block!!
       name = event:attr("name").klog("create_well_known got attr(name): ");
       parent_results = wrangler:parent();
       parent = parent_results{'parent'};
       parent_eci = parent[0]; // eci is the first element in tuple
       attrs = {}.put(["name"], name)
                      .put(["name_space"],"Fleet_Subscriptions")
                      .put(["my_role"],"Vehicle")
                      .put(["your_role"],"Fleet")
                      .put(["target_eci"],parent_eci.klog("target Eci: "))
                      .put(["channel_type"],"Fleet_Lab")
                      .put(["attrs"],meta:eci)
                      ;
    }
    always {
      raise wrangler event "subscription"
      attributes attrs;
    }
	}
}