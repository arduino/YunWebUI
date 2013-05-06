<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
  <meta name="viewport" content="initial-scale=1.0, user-scalable=no"/>
  <link rel="stylesheet" href="../assets/etheris.css" type="text/css"/>
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
              <input id="saveForm" name="saveForm" class="btTxt submit" type="submit" value="Configure">
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

    </div>
  </div>
  <!-- #content -->
  <br class="clear"/>
</div>
<!-- #container -->
</body>
</html>

