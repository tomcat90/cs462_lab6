
ruleset echo {
  meta {
    name "Echo"
    description <<
For a lab I have to write
>>
    author "Thomas Tingey"
    logging on
    sharing on
    provides hello

  }
  global {
    hello = function(obj) {
      msg = "Hello " + obj
      msg
    };

  }
  rule hello {
    select when echo hello
    pre{
      name = event:attr("name").klog("our passed in Name: ");
    }
    {
      send_directive("say") with
        something = "Hello World";
    }
    always {
        log ("LOG says Hello " + name);
    }
  }
  rule message {
    select when echo message
    pre{
      input = event:attr("event");
    }
    {
      send_directive("say") with
        something = "#{input}";
    }
  }

}