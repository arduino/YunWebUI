<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
  <meta name="viewport" content="initial-scale=1.0, user-scalable=no"/>
  <link rel="stylesheet" href="../assets/etheris.css" type="text/css"/>
  <script type="text/javascript" src="../assets/check.js"></script>
  <title>Etheris</title>
</head>
<body>
<div id="container">
  <div id="header">
    <div class="wrapper">
      <h1>Etheris</h1>
      <div id="logo"><img src="../assets/logo.png" alt="Etheris"/></div>
    </div>
  </div>
  <div id="content">
    <div class="wrapper">
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
              <input id="wifi.password" name="wifi.password" type="password" value="" maxlength="255" tabindex="4" required="">
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
              Password <span class="req">*</span>
            </label>

            <div class="input_container">
              <input id="password" name="password" type="password" maxlength="255" tabindex="6">
            </div>
          </li>

          <li>
            <div class="input_container">
              <input id="saveForm" name="saveForm" class="btTxt submit" type="submit" value="Configure &amp; Restart" tabindex="6">
            </div>
          </li>

        </ul>
      </form>
    </div>
  </div>
  <!-- #content -->
  <br class="clear"/>
</div>
<!-- #container -->
</body>
</html>