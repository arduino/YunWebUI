import socket

import json

def send_command(command_parts):
  try:
    bridge = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    bridge.settimeout(5)
    bridge.connect(("localhost", 6571))
  
    command = json.write(command_parts)
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
        return json_response
      except json.ReadException as json_ex:
        # json parse error. read more data and retry
        pass
  finally:
    bridge.close()
