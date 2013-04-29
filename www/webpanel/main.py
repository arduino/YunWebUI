import os
import subprocess
import hashlib
from bottle import route, run, template, static_file, request, response, error, hook
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
