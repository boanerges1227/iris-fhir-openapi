#!/usr/bin/env python3
"""Create a random, limited test account in an explicitly selected test container."""
import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess


def main():
    # Never replace an existing account or credential file; each run owns a fresh identity.
    parser = argparse.ArgumentParser()
    parser.add_argument('--container', required=True)
    parser.add_argument('--output', default='.local/rest-test-auth.json')
    args = parser.parse_args()
    path = Path(args.output)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    user = 'FHIRT' + secrets.token_hex(8)
    password = 'Aa1!' + secrets.token_hex(24)
    password_expr = '_'.join('$char(%d)' % ord(char) for char in password)
    commands = f'''set role=##class(FHIR.OpenAPI.Access).Resource("USER")_"_Admin"
set $Namespace="%SYS"
if ##class(Security.Users).Exists("{user}") write "TEST_USER_COLLISION",! halt
set p("FullName")="FHIR OpenAPI temporary test",p("Password")={password_expr},p("Roles")=role_",%DB_USER",p("Enabled")=1,p("Namespace")="USER"
set sc=##class(Security.Users).Create("{user}",.p)
if $SYSTEM.Status.IsError(sc) do $SYSTEM.Status.DisplayError(sc) halt
write "TEST_USER_CREATED",!
halt
'''
    try:
        result = subprocess.run(['docker', 'exec', '-i', args.container, 'iris', 'session', 'IRIS', '-U', 'USER'], input=commands, text=True, capture_output=True, check=True, timeout=30)
        if 'TEST_USER_CREATED' not in result.stdout or 'ERROR #' in result.stdout or '<SYNTAX>' in result.stdout:
            raise RuntimeError('IRIS did not confirm test user creation')
        with os.fdopen(fd, 'w') as stream:
            fd = -1
            json.dump({'user': user, 'password': password}, stream)
        print(f'Test account created; credentials stored in {path} (mode 0600).')
    except BaseException:
        if fd >= 0:
            os.close(fd)
        path.unlink(missing_ok=True)
        raise


if __name__ == '__main__':
    main()
