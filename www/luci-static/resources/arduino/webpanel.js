"use strict";

/*
 * This file is part of YunWebUI.
 *
 * YunWebUI is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * As a special exception, you may use this file as part of a free software
 * library without restriction.  Specifically, if other files instantiate
 * templates or use macros or inline functions from this file, or you compile
 * this file and link it with other files to produce an executable, this
 * file does not by itself cause the resulting executable to be covered by
 * the GNU General Public License.  This exception does not however
 * invalidate any other reasons why the executable file might be covered by
 * the GNU General Public License.
 *
 * Copyright 2013 Arduino LLC (http://www.arduino.cc/)
 */

function formCheck(form) {
  var wifi_ssid = form["wifi.ssid"];
  var wifi_encryption = form["wifi.encryption"];
  var wifi_password = form["wifi.password"];
  var hostname = form["hostname"];
  var password = form["password"];
  var errors;

  var errContainer = document.getElementById("error_response");

  errContainer.innerHTML = "";
  errors = false;

  wifi_password.className = "normal";
  wifi_ssid.className = "normal";
  hostname.className = "normal";
  password.className = "normal";
  errContainer.className = "hidden";

  function nullOrEmpty(val) {
    return val == null || val === "";
  }

  if (!wifi_ssid.disabled && nullOrEmpty(wifi_ssid.value)) {
    errorHandler(wifi_ssid, errContainer, "Please choose a WiFi network name");
    errors = true;
  }

  if (!wifi_password.disabled && wifi_encryption.value != "none") {
    if (nullOrEmpty(wifi_password.value)) {
      errorHandler(wifi_password, errContainer, "Please choose a WiFi password");
      errors = true;
    } else if (wifi_encryption.value != "wep" && wifi_password.value.length < 8) {
      errorHandler(wifi_password, errContainer, "WiFi password should be 8 char at least");
      errors = true;
    }
  }

  if (nullOrEmpty(hostname.value)) {
    errorHandler(hostname, errContainer, "Please choose a name for your Y&uacute;n");
    errors = true;

  } else if (hostname.value.match(/[^a-zA-Z0-9]/)) {
    errorHandler(hostname, errContainer, "You can only use alphabetical characters for the hostname (A-Z or a-z)");
    errors = true;
  }

  if (password.value != null && password.value != "" && password.value.length < 8) {
    errorHandler(password, errContainer, "Password should be 8 char at least");
    errors = true;
  } else if (!passwords_match()) {
    errorHandler(password, errContainer, "Passwords do not match");
    errors = true;
  }

  return !errors;
}

function formReset() {
  setTimeout(function() {
    grey_out_wifi_conf(!document.getElementById("wificheck").checked);
    onchange_security(document.getElementById("wifi_encryption"));
  }, 100);
}

function errorHandler(el, er, msg) {
  el.className = "error";
  er.className = "visible";
  er.innerHTML = "<p>" + er.innerHTML + msg + "<br /></p>";
}

function goto(href) {
  document.location = href;
  return false;
}

function onchange_security(select) {
  var wifi_pass_container = document.getElementById("wifi_password_container");
  var wifi_pass = document.getElementById("wifi_password");
  if (select.value == "none") {
    wifi_pass_container.setAttribute("class", "hidden");
  } else {
    wifi_pass_container.removeAttribute("class");
    wifi_pass.value = "";
    wifi_pass.focus();
  }
}

var pu, key_id, public_key;
if (typeof(getPublicKey) === "function") {
  pu = new getPublicKey(pub_key);
  key_id = pu.keyid;
  public_key = pu.pkey.replace(/\n/g, "");
}

function send_post(url, form, real_form_id) {
  var json = {};
  for (var i = 3; i < arguments.length; i++) {
    if (!form[arguments[i]].disabled) {
      json[arguments[i]] = form[arguments[i]].value;
    }
  }
  var pgp_message = doEncrypt(key_id, 0, public_key, JSON.stringify(json));
  var real_form = document.getElementById(real_form_id);
  real_form.pgp_message.value = pgp_message;
  real_form.submit();
  return false;
}

function grey_out_wifi_conf(disabled) {
  if (disabled) {
    document.getElementById("wifi_container").setAttribute("class", "disabled");
  } else {
    document.getElementById("wifi_container").setAttribute("class", "");
  }
  document.getElementById("wifi_password").disabled = disabled;
  document.getElementById("wifi_ssid").disabled = disabled;
  document.getElementById("wifi_encryption").disabled = disabled;
  document.getElementById("detected_wifis").disabled = disabled;
}

function passwords_match() {
  var confpassword = document.getElementById("confpassword");
  var password = document.getElementById("password");
  return confpassword.value == password.value;
}

function show_message_is_passwords_dont_match() {
  if (passwords_match()) {
    document.getElementById("pass_mismatch").setAttribute("class", "hidden error_container input_message");
  } else {
    document.getElementById("pass_mismatch").setAttribute("class", "error_container input_message");
  }
}

function onclick_upload() {
  $("#progress_bar_upload").attr("style", "");
  $("#upload_button").addClass("btn").attr("disabled", "true");
}

document.body.onload = function() {
  if ($("#progress_bar_upload").length > 0) {
    $("#upload_button").click(onclick_upload);
  }

  if (document.getElementById("username")) {
    document.getElementById("password").focus();
  }
  var wificheck = document.getElementById("wificheck");
  if (wificheck) {
    wificheck.onclick = function(event) {
      grey_out_wifi_conf(!event.target.checked);
    }
  }
  var wifi_encryption = document.getElementById("wifi_encryption");
  if (wifi_encryption) {
    wifi_encryption.onchange = function(event) {
      onchange_security(event.target);
    }
  }
  var confpassword = document.getElementById("confpassword");
  if (confpassword) {
    confpassword.onkeyup = show_message_is_passwords_dont_match;
    document.getElementById("password").onkeyup = show_message_is_passwords_dont_match;
  }

  var dmesg = document.getElementById("dmesg");
  if (dmesg) {
    $("#dmesg").hide();
    $("#dmesg_toogle").on("click", function() {
      if ($(this).text() == "Show") {
        $("#dmesg").show();
        $(this).text("Hide");
      } else {
        $("#dmesg").hide();
        $(this).text("Show");
      }
      return false;
    });
  }

  var detected_wifis = document.getElementById("detected_wifis");
  if (detected_wifis) {
    var detect_wifi_networks = function() {
      var detected_wifis = $("#detected_wifis");
      if (detected_wifis[0].disabled) {
        return false;
      }
      detected_wifis.empty();
      detected_wifis.append("<option>Detecting ...</option>");
      $.get(refresh_wifi_url, function(wifis) {
        detected_wifis.empty();
        detected_wifis.append("<option>Select a wifi network...</option>");
        for (var idx = 0; idx < wifis.length; idx++) {
          var html = "<option value=\"" + wifis[idx].name + "|||" + wifis[idx].encryption + "\">" + wifis[idx].name + " (";
          if (wifis[idx].encryption !== "none") {
            html = html + wifis[idx].pretty_encryption + ", ";
          }
          html = html + "quality " + wifis[idx].signal_strength + "%";
          html = html + ")</option>";
          detected_wifis.append(html);
        }
      });
      return false;
    };
    document.getElementById("refresh_detected_wifis").onclick = detect_wifi_networks;

    detected_wifis.onchange = function() {
      var parts = $("#detected_wifis").val().split("|||");
      if (parts.length !== 2) {
        return;
      }
      $("#wifi_ssid").val(parts[0]);
      var $wifi_encryption = $("#wifi_encryption");
      $wifi_encryption.val(parts[1]);
      $wifi_encryption.change();
    };
    detect_wifi_networks();
  }

  var restopen = document.getElementById("restopen");
  if (restopen) {
    var toogle_rest_api = function() {
      var data = {};
      data[this.name] = $(this).val();
      $.post(this.form.action, data);
    };
    restopen.onclick = toogle_rest_api;
    document.getElementById("restpass").onclick = toogle_rest_api;
  }
};
