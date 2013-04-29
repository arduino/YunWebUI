# coding=UTF-8

import os
import subprocess
import hashlib
from bottle import route, run, template, static_file, request, response, error, hook
from collections import OrderedDict
import conf

VIEWS_ROOT = "/www/webpanel/views/"
if os.environ.get("VIEWS_ROOT") != None:
  VIEWS_ROOT = os.environ["VIEWS_ROOT"] + VIEWS_ROOT

def redirect(location):
  response.status = 302
  response.set_header("Location", location)

@hook("before_request")
def check_credentials():
  error = False
  pwd = conf.get_stored_password()
  if pwd != "" and pwd != request.cookies.get("pwd"):
    error = True

  if error:
    if request.path in ["/upload"]:
      raise Exception("Wrong credentials")
    elif request.path in ["/", "/config"]:
      redirect("/set_password")

@route("/")
def index():
  config = conf.read_conf()
  config["active_interfaces"] = conf.read_actual_status()
  return template("index", config)

@route("/set_password")
def set_password_get():
  return static_file("set_password.html", root=VIEWS_ROOT)

@route("/set_password", method="POST")
def set_password_post():
  response.set_cookie("pwd", hashlib.sha512(request.forms.password).hexdigest())
  redirect("/")

@route("/config")
def index():
  config = conf.read_conf()
  config["root"] = VIEWS_ROOT
  config["countries"] = OrderedDict([("AL", "ALBANIA"), ("DZ", "ALGERIA"), ("AD", "ANDORRA"), ("AR", "ARGENTINA"), ("AW", "ARUBA"), ("AU", "AUSTRALIA"), ("AT", "AUSTRIA"), ("AZ", "AZERBAIJAN"), ("BH", "BAHRAIN"), ("BD", "BANGLADESH"), ("BB", "BARBADOS"), ("BY", "BELARUS"), ("BE", "BELGIUM"), ("BZ", "BELIZE"), ("BO", "BOLIVIA, PLURINATIONAL STATE OF"), ("BA", "BOSNIA AND HERZEGOVINA"), ("BR", "BRAZIL"), ("BN", "BRUNEI DARUSSALAM"), ("BG", "BULGARIA"), ("KH", "CAMBODIA"), ("CA", "CANADA"), ("CL", "CHILE"), ("CN", "CHINA"), ("CO", "COLOMBIA"), ("CR", "COSTA RICA"), ("HR", "CROATIA"), ("CY", "CYPRUS"), ("CZ", "CZECH REPUBLIC"), ("DK", "DENMARK"), ("DO", "DOMINICAN REPUBLIC"), ("EC", "ECUADOR"), ("EG", "EGYPT"), ("SV", "EL SALVADOR"), ("EE", "ESTONIA"), ("FI", "FINLAND"), ("FR", "FRANCE"), ("GE", "GEORGIA"), ("DE", "GERMANY"), ("GR", "GREECE"), ("GL", "GREENLAND"), ("GD", "GRENADA"), ("GU", "GUAM"), ("GT", "GUATEMALA"), ("HT", "HAITI"), ("HN", "HONDURAS"), ("HK", "HONG KONG"), ("HU", "HUNGARY"), ("IS", "ICELAND"), ("IN", "INDIA"), ("ID", "INDONESIA"), ("IR", "IRAN, ISLAMIC REPUBLIC OF"), ("IE", "IRELAND"), ("IL", "ISRAEL"), ("IT", "ITALY"), ("JM", "JAMAICA"), ("JP", "JAPAN"), ("JO", "JORDAN"), ("KZ", "KAZAKHSTAN"), ("KE", "KENYA"), ("KP", "KOREA, DEMOCRATIC PEOPLE'S REPUBLIC OF"), ("KR", "KOREA, REPUBLIC OF"), ("KW", "KUWAIT"), ("LV", "LATVIA"), ("LB", "LEBANON"), ("LI", "LIECHTENSTEIN"), ("LT", "LITHUANIA"), ("LU", "LUXEMBOURG"), ("MO", "MACAO"), ("MK", "MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF"), ("MY", "MALAYSIA"), ("MT", "MALTA"), ("MX", "MEXICO"), ("MC", "MONACO"), ("MA", "MOROCCO"), ("NP", "NEPAL"), ("NL", "NETHERLANDS"), ("NZ", "NEW ZEALAND"), ("NO", "NORWAY"), ("OM", "OMAN"), ("PK", "PAKISTAN"), ("PA", "PANAMA"), ("PG", "PAPUA NEW GUINEA"), ("PE", "PERU"), ("PH", "PHILIPPINES"), ("PL", "POLAND"), ("PT", "PORTUGAL"), ("PR", "PUERTO RICO"), ("QA", "QATAR"), ("RO", "ROMANIA"), ("RU", "RUSSIAN FEDERATION"), ("RW", "RWANDA"), ("BL", "SAINT BARTHÉLEMY"), ("SA", "SAUDI ARABIA"), ("RS", "SERBIA"), ("SG", "SINGAPORE"), ("SK", "SLOVAKIA"), ("SI", "SLOVENIA"), ("ZA", "SOUTH AFRICA"), ("ES", "SPAIN"), ("LK", "SRI LANKA"), ("SE", "SWEDEN"), ("CH", "SWITZERLAND"), ("SY", "SYRIAN ARAB REPUBLIC"), ("TW", "TAIWAN, PROVINCE OF CHINA"), ("TH", "THAILAND"), ("TT", "TRINIDAD AND TOBAGO"), ("TN", "TUNISIA"), ("TR", "TURKEY"), ("UA", "UKRAINE"), ("AE", "UNITED ARAB EMIRATES"), ("GB", "UNITED KINGDOM"), ("US", "UNITED STATES"), ("UY", "URUGUAY"), ("UZ", "UZBEKISTAN"), ("VE", "VENEZUELA, BOLIVARIAN REPUBLIC OF"), ("VN", "VIET NAM"), ("YE", "YEMEN"), ("ZW", "ZIMBABWE")])
  return template("config", config)

@route("/config", method="POST")
def configure():
#  try:
  conf.update_conf(request.forms)
  redirect("/config")
#  except Exception as e:
#    raise e
#    redirect("/?error=%(message)s" % { "message": e.message })

@route("/upload", method="POST")
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
    sketch = sketch[:len(sketch) - 1]
    with open("/etc/config/Caterina-Leonardo.hex", "r") as f:
      bootloader = f.readlines()
    # appending bootloader to sketch
    sketch = sketch + bootloader
    # saving final sketch
    with open("/tmp/" + upload.filename, "w") as f:
      f.writelines(sketch)

    command = ["avrdude", "-C/arduino/tools/avrdude.conf", "-q", "-q", "-patmega32u4", "-cavr109", "-P/dev/ttyACM0", "-b57600", "-D", "-Uflash:w:/tmp/" + upload.filename + ":i"]
    command = ["echo"] + command
    proc = subprocess.Popen(args=command, bufsize=1, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    returncode = proc.wait()
    print proc.stdout.read()
    print proc.stderr.read()
    print returncode
  finally:
    os.remove("/tmp/" + upload.filename)

run(host='0.0.0.0', port=6571)
