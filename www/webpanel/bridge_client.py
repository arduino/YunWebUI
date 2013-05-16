import socket

import json

def send_command(command, params):
  request = {
    "command": command
  }
  if command == "raw":
    request["data"] = params
  elif command == "get":
    request["key"] = params.split("/")[0]
  elif command == "put":
    params_parts = params.split("/")
    request["key"] = params_parts[0]
    request["value"] = params_parts[1]
  else:
    raise Exception("unknown command")

  try:
    bridge = socket.create_connection(("127.0.0.1", 5700), 5, ("127.0.0.1", 0))
    
    command = json.write(request)
    while len(command) > 0:
      sent = bridge.send(command)
      command = command[sent:]

    command_response = ""
    while True:
      try:
        command_response += bridge.recv(4096)
        if command_response == "":
          return None
        json_response, l = json.read(command_response)
        command_response = json.write(json_response)
        return command_response
      except json.ReadException as json_ex:
        # json parse error. read more data and retry
        pass
  finally:
    bridge.close()
