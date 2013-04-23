<!DOCTYPE html>
<html>
<body>

Welcome to Arduino DogStick<br/><br/>

<form action="/config" method="post">
Choose a name for you DogStick: it will make easier to find it<br/>
Name: <input type="text" name="hostname" value="{{hostname}}"/><br/>
<br/>
Set up a password: this will be used the next time you'll access the web panel and to upload new sketches<br/>
DogStick password: <input type="password" name="password"/><br/>
<br/>
Set up your wireless<br/>
SSID: <input type="text" name="wifi.ssid" value="{{wifi['ssid']}}"/><br/>
Encryption: <select name="wifi.encryption">
<option value="none" 
%if wifi['encryption'] == 'none': 
selected 
%end
>None</option>
<option value="wep" 
%if wifi['encryption'] == 'wep': 
selected 
%end
>WEP</option>
<option value="psk" 
%if wifi['encryption'] == 'psk': 
selected 
%end
>WPA-PSK</option>
<option value="psk2" 
%if wifi['encryption'] == 'psk2': 
selected 
%end
>WPA2-PSK</option>
</select><br/>
Password: <input type="password" name="wifi.password"/><br/>
<input type="submit" value="Configure and restart now!" />
</form>
</body>
</html>
