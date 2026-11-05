# IRIS FHIR OpenAPI

English | [简体中文](README.zh-CN.md)

Generate an OpenAPI 3.0.3 JSON document from a FHIR R4 CapabilityStatement inside InterSystems IRIS or IRIS for Health. The resulting document helps an enterprise API Gateway team understand and configure the FHIR endpoints a server declares.

The native ObjectScript module provides an English management UI, REST API, and terminal entry point. It can read a local FHIR endpoint, an explicitly registered HTTP(S) source, or an uploaded CapabilityStatement JSON file. The runtime does not depend on Python, Node.js, an external web service, or AI.

**Development version: 0.1.0.** The project is not yet published to a public IPM registry. A previously generated local `dist` archive is not included in the repository and predates the later English UI changes. Use the current source for those changes.

## How it works

1. Install the module in the target namespace and authorize a user.
2. Select a local FHIR endpoint, a registered HTTP(S) source, or a JSON file.
3. Preview the declared resources and interactions; choose the public scope and gateway settings.
4. Generate and review the specification and diagnostic report, then deliver the JSON to the gateway team.

Only metadata is read; the module does not call patient-data endpoints. The output represents the source's declared capabilities, not a guarantee that a particular caller can use every operation through a gateway.

## Supported output

- Declared resource read, version read, create, update, delete, patch, search and history interactions, plus system batch and transaction.
- Resource and interaction filters, public gateway base URL, selected conditional interactions, security declarations, and report/strict policies.
- Declared search parameters for GET and POST form search, preserving FHIR string syntax.
- A single JSON document with internal schema references, stable key ordering, source hash, coverage counts, and diagnostics.
- A **simplified gateway schema** suitable for routing and documentation; it is not a complete FHIR or profile validator.

Custom operations are reported with their name, canonical definition and source location; their paths and methods are not guessed. Unresolved imports, unknown modifier extensions and invalid consumed fields block generation.

## Requirements

- InterSystems IRIS or IRIS for Health with permission to install code and configure security in the target namespace.
- For the local source, a supported and licensed FHIR server configured in that namespace. Plain IRIS can use file and HTTP sources.
- For HTTPS source collection, an existing client SSL configuration with certificate-chain verification and the caller permissions described below.
- A separate code database for each independent installation: installations sharing a routines database cannot be upgraded or uninstalled independently.

The module does not create a FHIR server, change existing FHIR endpoints, or assign users a role during installation. Docker, Python, and OpenSSL are needed only for the optional development workflow.

## Installation

### IPM from local source

In the target namespace, using an account with IRIS security administration and namespace code/data access:

```objectscript
zpm "load /path/to/iris-fhir-openapi"
```

If you have a previously generated local offline archive, it predates the later English UI changes:

```objectscript
zpm "load /path/to/iris-fhir-openapi-0.1.0.tgz"
```

The default login URL is `/fhir-openapi-<lowercase-namespace>_login/index.html`, for example `/fhir-openapi-user_login/index.html`. After login, the management page is `/fhir-openapi-user/`. Installation checks ownership of the application paths and static files before copying.

### Manual import

Run in the target namespace, replacing both paths with paths accessible to the IRIS server:

```objectscript
set sc=$SYSTEM.OBJ.LoadDir("/path/to/iris-fhir-openapi/src","ck",,1)
if $SYSTEM.Status.IsError(sc) do $SYSTEM.Status.DisplayError(sc)
set sc=##class(FHIR.OpenAPI.Install).Setup($namespace,"/fhir-openapi","/path/to/iris-fhir-openapi/web")
if $SYSTEM.Status.IsError(sc) do $SYSTEM.Status.DisplayError(sc)
```

Check both statuses. With this example, open `/fhir-openapi_login/index.html`; the management page is `/fhir-openapi/`.

### Grant access

In the installation namespace, obtain the exact role name:

```objectscript
write ##class(FHIR.OpenAPI.Access).Resource()_"_Admin",!
```

An administrator assigns that role to the user in Management Portal. The user must also have the appropriate namespace/database access; local FHIR reads remain subject to the endpoint's own permissions. The role name contains a namespace digest to prevent collisions.

The separate anonymous login application serves only fixed static files and cannot execute CSP or REST. Management pages, REST methods and the service entry point require authentication and the module USE privilege. The module does not grant `%All` or database privileges to the application. Configure HTTPS and enterprise authentication according to the deployment environment.

## Use the management page

1. Sign in with an authorized IRIS account.
2. Choose **Current Namespace FHIR Endpoint**, **Registered HTTP(S) Endpoint**, or **Upload CapabilityStatement JSON**.
3. Select **Read & Preview** and inspect the declared resources, interactions and diagnostics.
4. Select the scope, enter the public gateway URL, API title/version and public API authentication, then select **Generate OpenAPI**.
5. Review the report and download `openapi.json` and `generation-report.json`.

If the source changes between preview and generation, generation returns 409; preview it again. Changing export settings invalidates the previous output. Source credentials are cleared after each request, so HTTP source credentials must be entered again before generation. They are not stored in browser persistent storage, the report or the generated specification.

## Source configuration

### Local FHIR endpoint

Use a specific path in the current namespace, such as `/fhir/r4`. The module dynamically uses the product endpoint strategy and `LoadMetadata` interface; it does not switch namespaces to fetch metadata. Local access requires the appropriate product, license, configured endpoint and permissions.

### Registered HTTP(S) endpoint

An administrator with existing security administration permissions registers the exact FHIR base URL, pinned IP address and SSL configuration:

```objectscript
set sc=##class(FHIR.OpenAPI.Config).RegisterSource("https://fhir.example.org/r4","192.0.2.10","CustomerFHIRClientTLS")
if $SYSTEM.Status.IsError(sc) do $SYSTEM.Status.DisplayError(sc)
```

The address is an example; replace it with the actual destination. The connection uses the registered IP while retaining the logical Host/SNI and validating both the trusted certificate chain and hostname. The fetch does not resolve DNS again, follow redirects, or forward the current IRIS session credentials.

**An HTTPS collection caller additionally needs existing `%Admin_Secure:USE` and system-namespace read access.** The module checks that the SSL configuration is enabled, is a client configuration and requires a trusted chain. It does not elevate privileges. A caller without these permissions can use a local or uploaded-file source where appropriate.

For local development only, explicitly allow a registered HTTP source:

```objectscript
set sc=##class(FHIR.OpenAPI.Config).RegisterSource("http://127.0.0.1:8091/fhir","127.0.0.1","",1)
if $SYSTEM.Status.IsError(sc) do $SYSTEM.Status.DisplayError(sc)
```

Source authentication supports anonymous, Basic and Bearer for each request. This is separate from the authentication described for the public API in the generated specification.

## Generation options and diagnostics

See [examples/file-request.json](examples/file-request.json) for a complete synthetic request. `publicBaseUrl` is the public FHIR base URL exposed by the gateway; `info` contains the API title and version. `resources.include` and `interactions.include` restrict the public scope. `searchMethods` selects GET and/or POST, `includeMetadata` controls `/metadata`, and `includeConditionalInteractions` enables supported collection-level conditional interactions. The supported `schemaMode` is `gateway`.

`security` describes public gateway authentication, independently of source credentials. Available OAuth scopes are not automatically required for every operation; use `security.requiredScopes` to specify required scopes. `failurePolicy: report` permits a result with warnings; `strict` blocks generation when warnings occur. Review the report's diagnostics and omitted items before handing the specification to a gateway team.

## REST API

Paths are relative to the management application:

| Method and path | Purpose |
|---|---|
| `GET /api/v1/health` | Authenticated module status and session CSRF token |
| `POST /api/v1/inspect` | Validate and preview the source; return `sourceHash` |
| `POST /api/v1/generate` | Generate specification and report with `expectedSourceHash` |

Use IRIS password authentication and a same-origin session. POST requests require the `X-CSRF-Token` returned by health; if an Origin is provided, it must match the host. First inspect the source, then copy the returned `sourceHash` to `expectedSourceHash` in the generation request. See the [file-source example](examples/file-request.json) and [REST integration script](scripts/test_rest.py). Do not put actual passwords in committed configuration.

Generation returns `httpStatus`, `status`, `openapi`, and `report`. On failure, `openapi` is null. Common statuses are 400 for configuration, 403 for permissions, 409 for a changed snapshot, 413 for oversized input, 422 for validation/generation, 429 for concurrency, 502 for upstream failure and 504 for timeout.

## ObjectScript terminal entry point

```objectscript
set input=##class(%Stream.FileCharacter).%New()
set input.Filename="/path/to/request.json"
set sc=##class(FHIR.OpenAPI.CLI).Generate(input,.specification,.report)
if $SYSTEM.Status.IsError(sc) do $SYSTEM.Status.DisplayError(sc)
```

The input has the same structure as [examples/file-request.json](examples/file-request.json). Check `%Status`; the caller decides where to write the returned specification and report streams. REST input cannot specify an arbitrary server file to read, and the module does not persist export history.

## Troubleshooting

- **403 after login:** check the module role and namespace/database access for the user. Local FHIR access also requires the endpoint's permissions.
- **Source not allowed or unsafe TLS:** have a security administrator check the exact registered URL, pinned IP, SSL configuration, trusted chain and caller permissions. HTTP must be explicitly allowed.
- **409:** preview the changed source again; re-enter HTTP source credentials if needed.
- **422:** inspect the report for unsupported FHIR versions, incomplete input and diagnostics. In strict mode, warnings also block output.
- **429 or 504:** the namespace has no free task slot or the request exceeded its time budget. Retry later and investigate the source response.

## Limits and compatibility

- FHIR R4 `4.0.1`, OpenAPI `3.0.3`, and JSON only in this release.
- Source metadata is limited to 10 MiB, REST bodies to 12 MiB, and generated specifications to 25 MiB of UTF-8. Browser downloads are compact JSON and checked again.
- At most two synchronous tasks per namespace; process locks release automatically when the process exits. There is no background queue.
- The overall budget is 30 seconds, checked during controlled traversal, serialization and HTTP reads. Network idle waiting is at most 15 seconds and connection waiting at most 5 seconds. A single underlying local `LoadMetadata` call cannot be forcibly preempted by this module.
- HTTP metadata reads support Content-Length, chunked and connection-close framing; compressed responses, redirects and proxy behavior are not supported.
- Schemas are simplified; profiles are not expanded and custom operations are reported rather than generated. Check the diagnostics.
- No patient data is used to create examples and no gateway configuration is automatically published.
- Tested on IRIS for Health Community 2026.2 and IRIS Community 2026.3 AI preview; untested older versions are not claimed compatible.

## Development and verification

Docker, Python 3 and OpenSSL are required for the development tests. Python dependencies are development-only:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
docker compose up --build -d
IRIS_TEST_CONTAINER=iris-fhir-openapi-test scripts/run-tests.sh
python3 scripts/create-test-user.py --container iris-fhir-openapi-test
python3 scripts/test_rest.py --base http://127.0.0.1:53985/fhir-openapi-user
.venv/bin/python scripts/validate_openapi.py .local/openapi.json
```

Compose binds port 53985 to localhost and creates a dedicated development instance; it does not create a FHIR server or a separate demo account. The unit script starts synthetic metadata services and creates a test certificate under `.local`. The explicit test-user script creates a random account with the module and USER database roles in the specified test container; its credential file `.local/rest-test-auth.json` is mode 0600 and is never overwritten. Supply another `--output` path for another run. Use dedicated test containers only; `.local`, test credentials and private keys are not part of the IPM package.

The Docker development image resets the built-in administrator to `_SYSTEM` / `SYS`. Open [http://127.0.0.1:53985/fhir-openapi-user_login/index.html](http://127.0.0.1:53985/fhir-openapi-user_login/index.html) and sign in with those credentials. This known password is for the isolated local Docker instance only; do not expose this image to an untrusted network or use it for production. IPM and manual installations do not reset administrator passwords. For the existing separately created test container the port may differ.

The latest clean-container run covered 41 IRIS tests and REST login/session, preview, generation, CSRF, 429, 409 and missing-hash checks with synthetic input. Earlier testing generated a specification from a local R4 endpoint and imported it into Kong 3.9; this does not imply compatibility with every gateway or product version.

## Uninstall

```objectscript
zpm "uninstall iris-fhir-openapi"
// For a manual installation, clean up the application and static configuration:
set sc=##class(FHIR.OpenAPI.Install).Uninstall()
if $SYSTEM.Status.IsError(sc) do $SYSTEM.Status.DisplayError(sc)
```

The module removes its owned entry points and managed static assets. Manual source files are not deleted. Security roles/resources and source registrations are retained for an administrator to review before cleanup; existing FHIR services, databases, namespaces and customer SSL configurations are not deleted.

## License

This project is distributed under the [MIT License](LICENSE).
