import os, pwd, grp

def drop_privileges(uid_name='nobody', gid_name='nogroup'):

  starting_uid = os.getuid()
  starting_gid = os.getgid()

  starting_uid_name = pwd.getpwuid(starting_uid)[0]

  if os.getuid() != 0:
    # We're not root so, like, whatever dude
    return

  # If we started as root, drop privs and become the specified user/group
  if starting_uid == 0:
    # Get the uid/gid from the name
    running_uid = pwd.getpwnam(uid_name)[2]
    running_gid = grp.getgrnam(gid_name)[2]

  # Try setting the new uid/gid
  try:
    os.setgid(running_gid)
  except OSError, e:
    log.error('Could not set effective group id: %s' % e)

  try:
    os.setuid(running_uid)
  except OSError, e:
    log.error('Could not set effective user id: %s' % e)

  # Ensure a very convervative umask
  new_umask = 077
  old_umask = os.umask(new_umask)

  final_uid = os.getuid()
  final_gid = os.getgid()
