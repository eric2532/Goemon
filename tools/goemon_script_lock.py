"""Wait on the launcher's existing POSIX record lock, then retain it across exec."""
import fcntl
import os
import sys


def main():
    lock_path, launcher, *arguments = sys.argv[1:]
    opened = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
    # Reserve an inheritable descriptor outside the shell's temporary FD range.
    # Close the original BEFORE locking: closing any descriptor for this inode
    # afterwards would release the process's POSIX record locks.
    held = fcntl.fcntl(opened, fcntl.F_DUPFD, 100)
    os.close(opened)
    os.set_inheritable(held, True)
    fcntl.lockf(held, fcntl.LOCK_EX)
    os.environ['GOEMON_SCRIPT_LOCK_FD'] = str(held)
    os.execv('/bin/zsh', ['/bin/zsh', launcher, *arguments])


if __name__ == '__main__':
    main()
