import hashlib
import shutil
import subprocess
import re
import os

ARDUINO_CONF = "/etc/arduino.conf"
SYSTEM_CONF = "/etc/config/system"
WIFI_CONF = "/etc/config/wireless"
NETWORK_CONFIGURED_CONF = "/etc/config/configured/network"
NETWORK_CONF = "/etc/config/network"

def read_file(filename):
  with open(filename) as f:
    lines = f.read().splitlines()
    return lines

def write_file(filename, data):
  for index, line in enumerate(data):
    if len(line) == 0 or line[len(line) - 1] != "\n":
      data[index] = line + "\n"
  with open(filename, "w") as f:
    f.writelines(data)

def get_conf_by_key(conf, key, sep):
  key_length = len(key)
  for line in conf:
    if line.find(key) == 0:
      value = line[line.find(sep, key_length) + 1:].strip()
      return value
  return ""

def set_conf_by_key(conf, key, sep, value):
  key_length = len(key)
  for index, line in enumerate(conf):
    if line.find(key) == 0:
      line = key + sep + value
      conf[index] = line

def get_stored_password():
  return get_conf_by_key(read_file(ARDUINO_CONF), "password", "=")

def modify_wireless_configuration_files(conf):
  if conf["password"].strip() != "":
    config = read_file(ARDUINO_CONF)
    set_conf_by_key(config, "password", "=", hashlib.sha512(conf["password"]).hexdigest())
    write_file(ARDUINO_CONF, config)
    config = read_file(ARDUINO_CONF)

  if conf["hostname"].strip() != "":
    system_config = read_file(SYSTEM_CONF)
    set_conf_by_key(system_config, "\toption hostname", "\t", conf["hostname"].replace(" ", "_"))
    write_file(SYSTEM_CONF, system_config)
    system_config = read_file(SYSTEM_CONF)

  wifi_config = read_file(WIFI_CONF)
  if conf["wifi.ssid"].strip() != "":
    set_conf_by_key(wifi_config, "\toption ssid", " ", "'" + conf["wifi.ssid"].replace(" ", "_") + "'")
  if conf["wifi.encryption"].strip() != "":
    set_conf_by_key(wifi_config, "\toption encryption", " ", "'" + conf["wifi.encryption"].replace(" ", "_") + "'")
  if conf["wifi.password"].strip() != "":
    set_conf_by_key(wifi_config, "\toption key", " ", "'" + conf["wifi.password"] + "'")
  set_conf_by_key(wifi_config, "\toption mode", " ", "'sta'")
  write_file(WIFI_CONF, wifi_config)
  shutil.copy2(NETWORK_CONFIGURED_CONF, NETWORK_CONF)

def read_conf():
  system_config_file = read_file(SYSTEM_CONF)
  hostname = get_conf_by_key(system_config_file, "\toption hostname", "\t")

  wireless_config_file = read_file("/etc/config/wireless")
  ssid = get_conf_by_key(wireless_config_file, "\toption ssid", " ").replace("'", "")
  encryption = get_conf_by_key(wireless_config_file, "\toption encryption", " ").replace("'", "")
  password = get_conf_by_key(wireless_config_file, "\toption key", " ").replace("'", "")

  conf = {
    "hostname": hostname,
    "wifi": {
      "ssid": ssid,
      "encryption": encryption,
      "password": password
    }
  }
  return conf

def read_ifconfig_for(interface):
  mo = re.search(r'^(?P<interface>[a-z0-9\-]+)\s+' +
                 r'Link encap:(?P<link_encap>\S+)\s+' +
                 r'(HWaddr\s+(?P<hardware_address>\S+))?' +
                 r'(\s+inet addr:(?P<ip_address>\S+))?' +
                 r'(\s+Bcast:(?P<broadcast_address>\S+)\s+)?' +
                 r'(Mask:(?P<net_mask>\S+)\s+)?',
                 interface, re.MULTILINE )
  if mo:
    info = mo.groupdict('')
    info['running'] = False
    info['up'] = False
    info['multicast'] = False
    info['broadcast'] = False
    if 'RUNNING' in interface:
      info['running'] = True
    if 'UP' in interface:
      info['up'] = True
    if 'BROADCAST' in interface:
      info['broadcast'] = True
    if 'MULTICAST' in interface:
      info['multicast'] = True
    return info
  return {}

def list_wireless_devices():
  devs = []
  with open("/proc/net/wireless") as w:
    lines = w.readlines()[2:]
    for line in lines:
      dev = line.strip().split(" ")[0].replace(":", "")
      devs.append(dev)
  return devs

def list_ethernet_devices():
  new_env = dict(os.environ)
  new_env["LANG"] = "en"
  proc = subprocess.Popen(args=["ifconfig"], bufsize=1, stdout=subprocess.PIPE, env=new_env)
  returncode = proc.wait()
  ifconfig = proc.stdout.read()
  return [ read_ifconfig_for(interface) for interface in ifconfig.split('\n\n') if interface.strip() ]

def read_actual_status():
  wireless = list_wireless_devices()
  ethernets = list_ethernet_devices()

  actual_status = []
  for eth in [eth for eth in ethernets if eth["ip_address"] != ""]:
    status = {
      "name": eth["interface"],
      "address": eth["ip_address"],
      "wireless": eth["interface"] in wireless,
      "mac": eth["hardware_address"]
    }
    actual_status.append(status)

  return actual_status
