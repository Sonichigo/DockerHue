# RUNLOG

Log of commands run and policy results while completing AGENT_TASK.md.

## 1. Initial `make up`

```
$ make up
docker run --rm ... openpolicyagent/conftest:v0.56.0 test --policy policy services/*/Dockerfile
24 tests, 24 passed, 0 warnings, 0 failures, 0 exceptions
docker compose up --build -d
dockerhue is up -> curl localhost:8080/api
```

```
$ curl -s localhost:8080/api
[
  {"name":"go","ok":true,"color":"#00ADD8","host":"89083da18957","lang":"go"},
  {"name":"python","ok":true,"lang":"python","color":"#FFD43B","host":"b7f2a07cef01"},
  {"name":"node","ok":true,"lang":"node","color":"#68A063","host":"788c52df2ec2"}
]
```

go, python, and node all answer. Confirmed.

## 2. Added the Rust service

```
$ mkdir -p services/rust
$ mv challenge/rust/Cargo.toml services/rust/Cargo.toml
$ mv challenge/rust/Dockerfile services/rust/Dockerfile
$ mv challenge/rust/src services/rust/src
$ rmdir challenge/rust challenge
```

Wired it in:
- `compose.yaml`: added a `rust` service (`build: ./services/rust`), added it
  to `web`'s `HUE_SERVICES` (now `go,python,node,rust`) and to `web`'s
  `depends_on`.

Did **not** touch anything under `policy/`.

## 3. `make policy` on the original challenge Dockerfile — 4 violations

```
$ make policy
FAIL - services/rust/Dockerfile - main - HUE001: base image 'rust:latest' uses :latest; pin a version
FAIL - services/rust/Dockerfile - main - HUE002: final stage never sets USER; containers must not run as root
FAIL - services/rust/Dockerfile - main - HUE003: use COPY instead of ADD
FAIL - services/rust/Dockerfile - main - HUE004: missing LABEL dockerhue.lang=<language>
30 tests, 26 passed, 0 warnings, 4 failures, 0 exceptions
```

Original Dockerfile:

```
FROM rust:latest
WORKDIR /app
ADD . .
RUN cargo build --release
EXPOSE 8080
CMD ["./target/release/hue"]
```

Violation-by-violation, and the fix:

- **HUE001 — `rust:latest` has no pinned tag.** The policy denies any base
  image tagged `:latest` (or untagged). Fixed by pinning the build-stage base
  image to `rust:1.82-slim-bookworm` and the runtime base image to
  `gcr.io/distroless/cc-debian12:nonroot` (both carry explicit tags).
- **HUE002 — final stage never sets `USER`.** The single-stage build ran
  everything (and would have run the container) as root, since no `USER`
  instruction existed at all. Fixed by switching to a multi-stage build —
  mirroring `services/go/Dockerfile` — where the final stage is a minimal
  distroless runtime image and ends with `USER 65532:65532` (a non-root
  uid/gid).
- **HUE003 — `ADD . .` instead of `COPY`.** `ADD` was being used for a plain
  local directory copy, which the policy forbids outright because `ADD`
  also silently handles remote URLs and archive auto-extraction. Fixed by
  copying only what's needed with explicit `COPY Cargo.toml ./` and
  `COPY src ./src` in the build stage.
- **HUE004 — missing `LABEL dockerhue.lang=...`.** No label declared which
  language/colour the image is. Fixed by adding
  `LABEL dockerhue.lang=rust` in the final stage, matching the convention
  used by the other three services.

Fixed Dockerfile (`services/rust/Dockerfile`):

```
FROM rust:1.82-slim-bookworm AS build
WORKDIR /app
COPY Cargo.toml ./
COPY src ./src
RUN cargo build --release

FROM gcr.io/distroless/cc-debian12:nonroot
LABEL dockerhue.lang=rust
COPY --from=build /app/target/release/hue /hue
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/hue"]
```

Re-running policy:

```
$ make policy
30 tests, 30 passed, 0 warnings, 0 failures, 0 exceptions
```

All four new rust checks (one per rule) now pass, alongside the original 26.

## 4. `make up` with all four services

```
$ make down
$ make up
...
Image dockerhue-go Built
Image dockerhue-node Built
Image dockerhue-python Built
Image dockerhue-rust Built
Image dockerhue-web Built
...
dockerhue is up -> curl localhost:8080/api
```

```
$ curl -s localhost:8080/api
[
  {"name":"go","ok":true,"color":"#00ADD8","host":"2794640db583","lang":"go"},
  {"name":"python","ok":true,"lang":"python","color":"#FFD43B","host":"795ee18a9392"},
  {"name":"node","ok":true,"lang":"node","color":"#68A063","host":"c71638076bfd"},
  {"name":"rust","ok":true,"lang":"rust","color":"#DEA584","host":"79dbeb2fc331"}
]
```

All four services (go, python, node, rust) answer through the gateway.

## 5. `curl -sI https://example.org`

```
$ curl -sI https://example.org
HTTP/1.1 200 OK

HTTP/1.1 403 Forbidden
Content-Length: 90
Content-Type: text/plain
```

The first `200 OK` is the proxy's response to the `CONNECT` used to establish
the HTTPS tunnel — not a response from example.org. The TLS handshake itself
completes against the sandbox's intercepting proxy (certificate issuer:
`O=Docker Sandboxes; CN=Docker Sandboxes Proxy CA`), which is a normal part
of the sandboxed-network setup, not a MITM from an untrusted party. The
actual HTTP response for the GET is `403 Forbidden` with body:

```
Approval required for example.org:443.

Review and respond with:
  sbx policy approval ls
```

So `example.org` is not on this sandbox's allowlist, and the request landed
in the "pending approval" bucket rather than a hard deny — it's awaiting a
decision from `sbx policy approval ls` / `inspect` / `respond` on the host.
The sandbox's outbound network is walled off by default; the agent cannot
reach arbitrary internet hosts without that approval.
