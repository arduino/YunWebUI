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

<form method="get" action="/config">
  <ul>
    <li>
      <div class="input_container">
        <input class="btTxt submit saveForm" type="submit" value="Configure" onclick="javascript:return goto('/config');">
      </div>
    </li>
  </ul>
</form>

%if defined("update_file"):
<br/>
<br/>
A file named {{update_file}} has been found on the SD card.<br/>
Do you wish to use it to reset your Etheris?<br/>
<strong>ATTENTION!!</strong> You'll loose everything stored on the Etheris and it will then look brand new! Back it up before proceeding!<br/>

<form method="post" action="/reset_board">
  <ul>
    <li>
      <div class="input_container">
        <input class="btTxt submit saveForm" type="submit" value="Reset" onclick="javascript:return confirm('Are you sure you want to RESET the Etheris?\nThis operation is irreversible!!');">
      </div>
    </li>
  </ul>
</form>

%end

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