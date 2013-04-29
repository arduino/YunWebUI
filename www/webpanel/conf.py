# coding=UTF-8

import hashlib
import shutil
import subprocess
import re
import os

UCI_KEY_PWD="arduino.@arduino[0].password"
UCI_KEY_HOSTNAME="system.@system[0].hostname"

UCI_KEY_WIFI_CHANNEL="wireless.radio0.channel"
UCI_KEY_WIFI_COUNTRY="wireless.radio0.country"
UCI_KEY_WIFI_SSID="wireless.@wifi-iface[0].ssid"
UCI_KEY_WIFI_ENCRYPTION="wireless.@wifi-iface[0].encryption"
UCI_KEY_WIFI_PWD="wireless.@wifi-iface[0].key"
UCI_KEY_WIFI_MODE="wireless.@wifi-iface[0].mode"

UCI_LAN_IFNAME="network.lan.ifname"
UCI_LAN_TYPE="network.lan.type"
UCI_LAN_PROTO="network.lan.proto"
UCI_LAN_IPADDR="network.lan.ipaddr"
UCI_LAN_NETMASK="network.lan.netmask"

def get_config_value(key):
  try:
    value = subprocess.check_output(["uci", "get", key])
    value = value.strip()

    if value == "":
      return value

    value = value.splitlines()[0]
    return value
  except subprocess.CalledProcessError as e: 
    return ""

def set_config_value(key, value):
  proc = subprocess.Popen(args=["uci", "set", key + "=" + value], bufsize=1)
  proc.wait()

def del_config(key):
  proc = subprocess.Popen(args=["uci", "delete", key], bufsize=1)
  proc.wait()

def uci_commit():
  proc = subprocess.Popen(args=["uci", "commit"], bufsize=1)
  proc.wait()

def get_stored_password():
  return get_config_value(UCI_KEY_PWD)

def update_conf(conf):
  if conf["password"].strip() != "":
    set_config_value(UCI_KEY_PWD, hashlib.sha512(conf["password"]).hexdigest())

  if conf["hostname"].strip() != "":
    set_config_value(UCI_KEY_HOSTNAME, conf["hostname"].replace(" ", "_"))

  set_config_value(UCI_KEY_WIFI_CHANNEL, "auto")
  set_config_value(UCI_KEY_WIFI_MODE, "sta")
  if conf["wifi.ssid"].strip() != "":
    set_config_value(UCI_KEY_WIFI_SSID, conf["wifi.ssid"])
  if conf["wifi.encryption"].strip() != "":
    set_config_value(UCI_KEY_WIFI_ENCRYPTION, conf["wifi.encryption"].replace(" ", "_"))
  if conf["wifi.password"].strip() != "":
    set_config_value(UCI_KEY_WIFI_PWD, conf["wifi.password"])
  if conf["wifi.country"].strip() != "":
    set_config_value(UCI_KEY_WIFI_COUNTRY, conf["wifi.country"])

  del_config(UCI_LAN_IFNAME)
  del_config(UCI_LAN_TYPE)
  del_config(UCI_LAN_IPADDR)
  del_config(UCI_LAN_NETMASK)
  set_config_value(UCI_LAN_PROTO, "dhcp")
  uci_commit()

def read_conf():
  hostname = get_config_value(UCI_KEY_HOSTNAME)
  ssid = get_config_value(UCI_KEY_WIFI_SSID)
  encryption = get_config_value(UCI_KEY_WIFI_ENCRYPTION)
  password = get_config_value(UCI_KEY_WIFI_PWD)
  country = get_config_value(UCI_KEY_WIFI_COUNTRY)

  conf = {
    "hostname": hostname,
    "wifi": {
      "ssid": ssid,
      "encryption": encryption,
      "password": password,
      "country": country
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
