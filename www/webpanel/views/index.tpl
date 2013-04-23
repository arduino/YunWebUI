<!DOCTYPE html>
<html>
<body>

Welcome to {{hostname}}, your Arduino DogStick<br/><br/>

This is my current network connection:
%for iface in active_interfaces:
  Name: {{iface["name"]}}
  %if iface["wireless"]:
    (wireless)
  %end
  <br/>
  Address: {{iface["address"]}}<br/>
  MAC address: {{iface["mac"]}}<br/>
  <br/>
%end

<br/>

<a href="/config">Configure me!</a>

</body>
</html>
