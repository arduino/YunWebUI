Welcome to {{hostname}}, your Arduino Etheris<br/><br/>

This is my current network connection:<br/>
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

<form id="form1" name="form1" method="get" action="/config">
  <ul>
    <li>
      <div class="input_container">
        <input id="saveForm" name="saveForm" class="btTxt submit" type="submit" value="Configure" onclick="javascript:document.location = '/config'; return false;">
      </div>
    </li>
  </ul>
</form>

%if defined("last_log"):
<br/>
There's been a problem last time I tried configuring wifi. Check the following log:<br/>
<textarea rows="20">
%for line in last_log:
{{line.strip()}}
%end
</textarea>
<script language="javascript">document.getElementsByTagName("textarea")[0].scrollTop = 99999;</script>
%end
%rebase layout