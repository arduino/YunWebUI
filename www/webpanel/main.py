# coding=UTF-8

import os
import subprocess
import hashlib
from collections import OrderedDict

from bottle import Bottle, route, run, template, static_file, request, response, hook, error, HTTPResponse
import conf
import bridge_client

class WrongCredentials(Exception):

  def __init__(self):
    super(WrongCredentials, self).__init__(self, "Wrong credentials!")


ROOT = "/www/webpanel"
if os.environ.get("ROOT") != None:
  ROOT = os.environ["ROOT"] + ROOT

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
  if pwd != None and pwd != "":
    return pwd

  auth = request.auth
  if auth != None:
    return hashlib.sha512(auth[1]).hexdigest()

  return ""

def check_if_update_file_available():
  try:
    output = subprocess.check_output("update-file-available", stderr=subprocess.STDOUT, shell=True)
    output = output.strip()
    output = output[output.rfind("/") + 1:]
    return output
  except subprocess.CalledProcessError as e:
    return None

@app.hook("before_request")
def check_credentials():
  error = False
  pwd = conf.get_stored_password()
  if pwd != "" and pwd != client_pwd(request):
    error = True

  if error:
    if request.path in ["/upload"] or request.route.rule in ["/board/<command:path>"]:
      raise WrongCredentials()
    if request.path in ["/set_password", "/ready"] or request.route.rule in ["/assets/<filename>"]:
      return
    if request.path not in ["/upload"]:
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
  ctx = conf.read_conf()
  ctx["active_interfaces"] = conf.read_actual_status()
  
  update_file = check_if_update_file_available()
  if update_file != None:
    ctx["update_file"] = update_file
  
  try:
    with open("/last_dmesg_with_wifi_errors.log") as last_log:
      ctx["last_log"] = last_log.readlines()
  except IOError:
    pass
  return template("index", ctx)

@app.route("/ready")
def are_you_ready():
  response.status = 200

@app.route("/set_password")
def set_password_get():
  return template("set_password")

@app.route("/set_password", method="POST")
def set_password_post():
  response.set_cookie("pwd", hashlib.sha512(request.forms.password).hexdigest())
  redirect("/")

@app.route("/config")
def index():
  ctx = conf.read_conf()
  ctx["countries"] = OrderedDict([("AL", "ALBANIA"), ("DZ", "ALGERIA"), ("AD", "ANDORRA"), ("AR", "ARGENTINA"), ("AW", "ARUBA"), ("AU", "AUSTRALIA"), ("AT", "AUSTRIA"), ("AZ", "AZERBAIJAN"), ("BH", "BAHRAIN"), ("BD", "BANGLADESH"), ("BB", "BARBADOS"), ("BY", "BELARUS"), ("BE", "BELGIUM"), ("BZ", "BELIZE"), ("BO", "BOLIVIA, PLURINATIONAL STATE OF"), ("BA", "BOSNIA AND HERZEGOVINA"), ("BR", "BRAZIL"), ("BN", "BRUNEI DARUSSALAM"), ("BG", "BULGARIA"), ("KH", "CAMBODIA"), ("CA", "CANADA"), ("CL", "CHILE"), ("CN", "CHINA"), ("CO", "COLOMBIA"), ("CR", "COSTA RICA"), ("HR", "CROATIA"), ("CY", "CYPRUS"), ("CZ", "CZECH REPUBLIC"), ("DK", "DENMARK"), ("DO", "DOMINICAN REPUBLIC"), ("EC", "ECUADOR"), ("EG", "EGYPT"), ("SV", "EL SALVADOR"), ("EE", "ESTONIA"), ("FI", "FINLAND"), ("FR", "FRANCE"), ("GE", "GEORGIA"), ("DE", "GERMANY"), ("GR", "GREECE"), ("GL", "GREENLAND"), ("GD", "GRENADA"), ("GU", "GUAM"), ("GT", "GUATEMALA"), ("HT", "HAITI"), ("HN", "HONDURAS"), ("HK", "HONG KONG"), ("HU", "HUNGARY"), ("IS", "ICELAND"), ("IN", "INDIA"), ("ID", "INDONESIA"), ("IR", "IRAN, ISLAMIC REPUBLIC OF"), ("IE", "IRELAND"), ("IL", "ISRAEL"), ("IT", "ITALY"), ("JM", "JAMAICA"), ("JP", "JAPAN"), ("JO", "JORDAN"), ("KZ", "KAZAKHSTAN"), ("KE", "KENYA"), ("KP", "KOREA, DEMOCRATIC PEOPLE'S REPUBLIC OF"), ("KR", "KOREA, REPUBLIC OF"), ("KW", "KUWAIT"), ("LV", "LATVIA"), ("LB", "LEBANON"), ("LI", "LIECHTENSTEIN"), ("LT", "LITHUANIA"), ("LU", "LUXEMBOURG"), ("MO", "MACAO"), ("MK", "MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF"), ("MY", "MALAYSIA"), ("MT", "MALTA"), ("MX", "MEXICO"), ("MC", "MONACO"), ("MA", "MOROCCO"), ("NP", "NEPAL"), ("NL", "NETHERLANDS"), ("NZ", "NEW ZEALAND"), ("NO", "NORWAY"), ("OM", "OMAN"), ("PK", "PAKISTAN"), ("PA", "PANAMA"), ("PG", "PAPUA NEW GUINEA"), ("PE", "PERU"), ("PH", "PHILIPPINES"), ("PL", "POLAND"), ("PT", "PORTUGAL"), ("PR", "PUERTO RICO"), ("QA", "QATAR"), ("RO", "ROMANIA"), ("RU", "RUSSIAN FEDERATION"), ("RW", "RWANDA"), ("BL", "SAINT BARTHÉLEMY"), ("SA", "SAUDI ARABIA"), ("RS", "SERBIA"), ("SG", "SINGAPORE"), ("SK", "SLOVAKIA"), ("SI", "SLOVENIA"), ("ZA", "SOUTH AFRICA"), ("ES", "SPAIN"), ("LK", "SRI LANKA"), ("SE", "SWEDEN"), ("CH", "SWITZERLAND"), ("SY", "SYRIAN ARAB REPUBLIC"), ("TW", "TAIWAN, PROVINCE OF CHINA"), ("TH", "THAILAND"), ("TT", "TRINIDAD AND TOBAGO"), ("TN", "TUNISIA"), ("TR", "TURKEY"), ("UA", "UKRAINE"), ("AE", "UNITED ARAB EMIRATES"), ("GB", "UNITED KINGDOM"), ("US", "UNITED STATES"), ("UY", "URUGUAY"), ("UZ", "UZBEKISTAN"), ("VE", "VENEZUELA, BOLIVARIAN REPUBLIC OF"), ("VN", "VIET NAM"), ("YE", "YEMEN"), ("ZW", "ZIMBABWE")])
  ctx["encryptions"] = OrderedDict([("none", "None"), ("wep", "WEP"), ("psk", "WPA"), ("psk2", "WPA2")])
  return template("config", ctx)

@app.route("/config", method="POST")
def configure():
  conf.update_conf(request.forms)
  subprocess.Popen(["reboot"])
  return template("reboot")

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
    with open("/etc/arduino/Caterina-Etheris.hex", "r") as f:
      bootloader = f.readlines()
    # appending bootloader to sketch
    sketch = sketch + bootloader
    # saving final sketch
    with open("/tmp/" + upload.filename, "w") as f:
      f.writelines(sketch)

    command = "run-avrdude /tmp/" + upload.filename
    if request.forms.params:
      command = command + " '" + request.forms.params + "'"
    try:
      output = subprocess.check_output(command, stderr=subprocess.STDOUT, shell=True)
      return HTTPResponse(output, status=200)
    except subprocess.CalledProcessError as e:
      return HTTPResponse(e.output, status=500)
  except Exception as e:
    return HTTPResponse(e.output, status=500)
  finally:
    os.remove("/tmp/" + upload.filename)

@app.route("/board/<command:path>", ["GET", "POST"])
def board_send_command(command):
  command_response = bridge_client.send_command(command.split("/"))

  if command_response != None:
    return command_response
  response.status = 200
  
@app.route("/reset_board", "POST")
def reset_board():
  update_file = check_if_update_file_available()
  if update_file is None:
    response.status = 500

  blink = subprocess.Popen(["blink-start", "50"])
  blink.wait()
  subprocess.Popen(["run-sysupgrade", update_file])
  return template("sysupgrade")

import threading
def run_server_on_port_80():
  app80 = Bottle()
  
  @app80.route("<whatever:path>", method="ANY")
  def redirect_to_https(whatever):
    ctx = {}
    ctx["new_url"] = request.url.replace("http:", "https:")
    return template("redirecting", ctx)
    
  app80.run(host="0.0.0.0", port=80)
    
app80thread = threading.Thread(target=run_server_on_port_80)
app80thread.daemon = True
app80thread.start()

app.run(host="0.0.0.0", server="securewsgiref", port=443)
