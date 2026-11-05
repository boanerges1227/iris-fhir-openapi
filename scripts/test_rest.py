"""Native REST integration verification; only accesses this project's dedicated test port."""
import argparse
import base64
import http.cookiejar
import json
import urllib.error
import urllib.request
import subprocess
from pathlib import Path


def run(base, auth_file, container):
    # Use session cookies and CSRF, simulating the admin page; test passwords are read only from a local restricted file.
    auth = json.loads(Path(auth_file).read_text())
    jar = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    authorization = 'Basic ' + base64.b64encode((auth['user'] + ':' + auth['password']).encode()).decode()

    def call(path, body=None, authenticated=True, token=None):
        headers = {'Content-Type': 'application/json'}
        if authenticated:
            headers['Authorization'] = authorization
        if token:
            headers['X-CSRF-Token'] = token
        req = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
        try:
            response = opener.open(req, timeout=40)
        except urllib.error.HTTPError as error:
            response = error
        data = response.read()
        try:
            data = json.loads(data)
        except ValueError:
            data = {}
        return response.status, data

    status, _ = call('/api/v1/health', authenticated=False)
    assert status in (401, 403), ('anonymous health', status)
    status, health = call('/api/v1/health')
    assert status == 200, ('health', status)
    token = health['csrfToken']
    # Verify that the authenticated session cookie works without another Basic header.
    status, session_health = call('/api/v1/health', authenticated=False)
    assert status == 200 and session_health['csrfToken'] == token, ('session health', status)
    request = json.loads(Path('examples/file-request.json').read_text())
    assert call('/api/v1/inspect', request)[0] == 403, 'CSRF must be required'
    status, preview = call('/api/v1/inspect', request, token=token)
    assert status == 200, ('inspect', status, preview)
    request['expectedSourceHash'] = preview['sourceHash']
    status, result = call('/api/v1/generate', request, token=token)
    assert status == 200, ('generate', status, result)
    Path('.local/openapi.json').write_text(json.dumps(result['openapi'], ensure_ascii=False, indent=2))
    Path('.local/generation-report.json').write_text(json.dumps(result['report'], ensure_ascii=False, indent=2))
    holder=subprocess.Popen(['docker','exec','-i',container,'iris','session','IRIS','-U','USER'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    holder.stdin.write('do ##class(Test.FHIROpenAPI.Service).HoldSlots()\nhalt\n');holder.stdin.flush()
    for line in holder.stdout:
        if 'SLOTS_HELD' in line:
            break
    assert call('/api/v1/generate',request,token=token)[0]==429, 'concurrency limit'
    holder.communicate(timeout=10)
    request['source']['capability']['name'] = 'changed'
    assert call('/api/v1/generate', request, token=token)[0] == 409
    request.pop('expectedSourceHash')
    assert call('/api/v1/generate', request, token=token)[0] == 400, 'REST snapshot expectation required'
    print('REST checks passed: anonymous, CSRF, preview, generation, 429 concurrency, 409 snapshot, required hash.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', default='http://127.0.0.1:53985/fhir-openapi-user')
    parser.add_argument('--auth', default='.local/rest-test-auth.json')
    parser.add_argument('--container', default='iris-fhir-openapi-test')
    args = parser.parse_args()
    run(args.base, args.auth, args.container)
