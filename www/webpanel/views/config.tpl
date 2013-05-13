<form id="form1" name="form1" method="post" action="/config" onsubmit="javascript:return formCheck(this);">
  <div id="error_container" class="hidden">
    <p>An error has occurred.</p>
  </div>
  <ul>
    <li>
      <label class="title">
        WiFi parameters
      </label>
      <br/>
    </li>

    <li>
      <label class="desc" for="wifi.country">
        You live in: <span class="req">*</span>
      </label>

      <div class="input_container">
        <select id="wifi.country" name="wifi.country" tabindex="1">
          <option value="00"
          %if wifi['country'] == '00':
          selected="selected"
          %end
          >Rest of the world</option>
          %for code in countries.keys():
          <option value="{{code}}"
          %if wifi['country'] == code:
          selected="selected"
          %end
          >{{countries[code]}}</option>
          %end
        </select>
      </div>
    </li>

    <li>
      <label class="desc" for="wifi.ssid">
        WiFi network name <span class="req">*</span>
      </label>

      <div class="input_container">
        <input id="wifi.ssid" name="wifi.ssid" type="text" value="{{wifi['ssid']}}" maxlength="255" tabindex="2">
      </div>
    </li>

    <li>
      <label class="desc" for="wifi.encryption">
        Security <span class="req">*</span>
      </label>

      <div class="input_container">
        <select id="wifi.encryption" name="wifi.encryption" tabindex="3">
          %for enc in encryptions.keys():
          <option value="{{enc}}"
          %if wifi['encryption'] == enc:
          selected="selected"
          %end
          >{{encryptions[enc]}}</option>
          %end
        </select>
      </div>
    </li>

    <li>
      <label class="desc" for="wifi.password">
        Password <span id="req_3" class="req">*</span>
      </label>

      <div class="input_container">
        <input id="wifi.password" name="wifi.password" type="password" value="" maxlength="255" tabindex="4">
      </div>
    </li>

    <li>
      <label class="title">
        Your Etheris
      </label>
      <br/>
    </li>

    <li>
      <label class="desc" for="hostname">
        Etheris name <span class="req">*</span>
      </label>

      <div class="input_container">
        <input id="hostname" name="hostname" type="text" value="{{hostname}}" maxlength="255" tabindex="5">
      </div>
    </li>

    <li>
      <label class="desc" for="password">
        Password
      </label>

      <div class="input_container">
        <input id="password" name="password" type="password" maxlength="255" tabindex="6">
      </div>
    </li>

    <li>
      <div class="input_container">
        <input class="btTxt submit saveForm" type="submit" value="Configure &amp; Restart" tabindex="6">
      </div>
    </li>

  </ul>
</form>
%rebase layout