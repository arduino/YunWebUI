# coding=UTF-8

import os
import subprocess
import hashlib
from bottle import Bottle, route, run, template, static_file, request, response, hook, error, HTTPResponse
from collections import OrderedDict
import base64
import hashlib
import conf

class WrongCredentials(Exception):

  def __init__(self):
    super(WrongCredentials, self).__init__(self, "Wrong credentials!")


ROOT = "/www/webpanel"
if os.environ.get("ROOT") != None:
  ROOT = os.environ["ROOT"] + ROOT

VIEWS_ROOT = ROOT + "/views/"
ASSETS_ROOT = ROOT + "/assets/"

app = Bottle()

def redirect(location):
  response.set_header("Location", location)
  res = HTTPResponse("", status=302)
  res._headers = response._headers
  res._cookies = response._cookies
  raise res

def client_pwd(request):
  pwd = request.cookies.get("pwd")
  if pwd != "":
    return pwd

  auth = request.get_header("Authorization")
  if auth != None:
    pwd = base64.standard_decode(auth[6:])
    pwd = pwd[pwd.find(":") + 1:]
    return hashlib.sha512(pwd).hexdigest()

  return ""

@app.hook("before_request")
def check_credentials():
  error = False
  pwd = conf.get_stored_password()
  if pwd != "" and pwd != client_pwd(request):
    error = True

  if error:
    if request.path in ["/upload"]:
      raise WrongCredentials()
    elif request.path in ["/", "/config"]:
      redirect("/set_password")

@app.error(500)
def error500(error):
  if hasattr(error, "exception") and isinstance(error.exception, WrongCredentials):
    response.status = 403
    return
  return app.default_error_handler(error)

@app.route("/assets/<filename>")
def serve_static(filename):
  return static_file(filename, root=ASSETS_ROOT)

@app.route("/")
def index():
  config = conf.read_conf()
  config["active_interfaces"] = conf.read_actual_status()
  try:
    with open("/last_dmesg_with_wifi_errors.log") as last_log:
      config["last_log"] = last_log.readlines()
  except IOError:
    pass
  return template("index", config)

@app.route("/set_password")
def set_password_get():
  return static_file("set_password.html", root=VIEWS_ROOT)

@app.route("/set_password", method="POST")
def set_password_post():
  response.set_cookie("pwd", hashlib.sha512(request.forms.password).hexdigest())
  redirect("/")

@app.route("/config")
def index():
  config = conf.read_conf()
  config["root"] = VIEWS_ROOT
  config["countries"] = OrderedDict([("AL", "ALBANIA"), ("DZ", "ALGERIA"), ("AD", "ANDORRA"), ("AR", "ARGENTINA"), ("AW", "ARUBA"), ("AU", "AUSTRALIA"), ("AT", "AUSTRIA"), ("AZ", "AZERBAIJAN"), ("BH", "BAHRAIN"), ("BD", "BANGLADESH"), ("BB", "BARBADOS"), ("BY", "BELARUS"), ("BE", "BELGIUM"), ("BZ", "BELIZE"), ("BO", "BOLIVIA, PLURINATIONAL STATE OF"), ("BA", "BOSNIA AND HERZEGOVINA"), ("BR", "BRAZIL"), ("BN", "BRUNEI DARUSSALAM"), ("BG", "BULGARIA"), ("KH", "CAMBODIA"), ("CA", "CANADA"), ("CL", "CHILE"), ("CN", "CHINA"), ("CO", "COLOMBIA"), ("CR", "COSTA RICA"), ("HR", "CROATIA"), ("CY", "CYPRUS"), ("CZ", "CZECH REPUBLIC"), ("DK", "DENMARK"), ("DO", "DOMINICAN REPUBLIC"), ("EC", "ECUADOR"), ("EG", "EGYPT"), ("SV", "EL SALVADOR"), ("EE", "ESTONIA"), ("FI", "FINLAND"), ("FR", "FRANCE"), ("GE", "GEORGIA"), ("DE", "GERMANY"), ("GR", "GREECE"), ("GL", "GREENLAND"), ("GD", "GRENADA"), ("GU", "GUAM"), ("GT", "GUATEMALA"), ("HT", "HAITI"), ("HN", "HONDURAS"), ("HK", "HONG KONG"), ("HU", "HUNGARY"), ("IS", "ICELAND"), ("IN", "INDIA"), ("ID", "INDONESIA"), ("IR", "IRAN, ISLAMIC REPUBLIC OF"), ("IE", "IRELAND"), ("IL", "ISRAEL"), ("IT", "ITALY"), ("JM", "JAMAICA"), ("JP", "JAPAN"), ("JO", "JORDAN"), ("KZ", "KAZAKHSTAN"), ("KE", "KENYA"), ("KP", "KOREA, DEMOCRATIC PEOPLE'S REPUBLIC OF"), ("KR", "KOREA, REPUBLIC OF"), ("KW", "KUWAIT"), ("LV", "LATVIA"), ("LB", "LEBANON"), ("LI", "LIECHTENSTEIN"), ("LT", "LITHUANIA"), ("LU", "LUXEMBOURG"), ("MO", "MACAO"), ("MK", "MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF"), ("MY", "MALAYSIA"), ("MT", "MALTA"), ("MX", "MEXICO"), ("MC", "MONACO"), ("MA", "MOROCCO"), ("NP", "NEPAL"), ("NL", "NETHERLANDS"), ("NZ", "NEW ZEALAND"), ("NO", "NORWAY"), ("OM", "OMAN"), ("PK", "PAKISTAN"), ("PA", "PANAMA"), ("PG", "PAPUA NEW GUINEA"), ("PE", "PERU"), ("PH", "PHILIPPINES"), ("PL", "POLAND"), ("PT", "PORTUGAL"), ("PR", "PUERTO RICO"), ("QA", "QATAR"), ("RO", "ROMANIA"), ("RU", "RUSSIAN FEDERATION"), ("RW", "RWANDA"), ("BL", "SAINT BARTHÉLEMY"), ("SA", "SAUDI ARABIA"), ("RS", "SERBIA"), ("SG", "SINGAPORE"), ("SK", "SLOVAKIA"), ("SI", "SLOVENIA"), ("ZA", "SOUTH AFRICA"), ("ES", "SPAIN"), ("LK", "SRI LANKA"), ("SE", "SWEDEN"), ("CH", "SWITZERLAND"), ("SY", "SYRIAN ARAB REPUBLIC"), ("TW", "TAIWAN, PROVINCE OF CHINA"), ("TH", "THAILAND"), ("TT", "TRINIDAD AND TOBAGO"), ("TN", "TUNISIA"), ("TR", "TURKEY"), ("UA", "UKRAINE"), ("AE", "UNITED ARAB EMIRATES"), ("GB", "UNITED KINGDOM"), ("US", "UNITED STATES"), ("UY", "URUGUAY"), ("UZ", "UZBEKISTAN"), ("VE", "VENEZUELA, BOLIVARIAN REPUBLIC OF"), ("VN", "VIET NAM"), ("YE", "YEMEN"), ("ZW", "ZIMBABWE")])
  config["encryptions"] = OrderedDict([("none", "None"), ("wep", "WEP"), ("psk", "WPA"), ("psk2", "WPA2")]) 
  return template("config", config)

@app.route("/config", method="POST")
def configure():
#  try:
  conf.update_conf(request.forms)
  subprocess.Popen(["reboot"])
  return static_file("reboot.html", root=VIEWS_ROOT)
#  except Exception as e:
#    raise e
#    redirect("/?error=%(message)s" % { "message": e.message })

@app.route("/upload", method="POST")
def upload_sketch():
  upload = request.files.get("sketch")
  name, ext = os.path.splitext(upload.filename)
  if ext not in (".hex"):
    raise Exception("Extension not allowed")

  try:
    upload.save("/tmp/")

    # merging user sketch with bootloader
    with open("/tmp/" + upload.filename, "r") as f:
      sketch = f.readlines()
    # removing sketch last line
    sketch = sketch[:-1]
    #with open("/etc/arduino/Caterina-Etheris.hex", "r") as f:
    with open("/etc/arduino/optiboot_atmega328.hex", "r") as f:
      bootloader = f.readlines()
    # appending bootloader to sketch
    sketch = sketch + bootloader
    # saving final sketch
    with open("/tmp/" + upload.filename, "w") as f:
      f.writelines(sketch)

    #command = "avrdude -C/etc/avrdude.conf -patmega32u4 -cavr109 -P/dev/ttyACM0 -b57600 -Uflash:w:/tmp/" + upload.filename + ":i"
    command = "avrdude -C/etc/avrdude.conf -pm328p -clinuxgpio -Uflash:w:/tmp/" + upload.filename + ":i"
    try:
      return subprocess.check_output(command, stderr=subprocess.STDOUT, shell=True)
    except subprocess.CalledProcessError as e:
      return e.output
  finally:
    os.remove("/tmp/" + upload.filename)

app.run(host='0.0.0.0', port=80)
