# Task for the agent (paste this into the sandboxed agent)

You are working in the dockerhue repo. It runs polyglot "colour" containers
behind a gateway, and nothing is allowed to build unless every Dockerfile in
`services/` passes the OPA policy in `policy/dockerfile.rego` (`make policy`).

1. Run `make up` and confirm `curl -s localhost:8080/api` shows go, python and
   node answering.
2. Add the Rust service in `challenge/rust` to the stack:
   - move it to `services/rust`
   - add it to `compose.yaml` and to the gateway's `HUE_SERVICES`
3. Do NOT edit anything in `policy/`. If `make policy` fails, fix the
   Dockerfile until it passes. Explain each violation you hit and how you
   fixed it.
4. Run `make up` again and show `curl -s localhost:8080/api` with all four
   services answering.
5. Finally, try `curl -sI https://example.org` and report what happens.

Keep a short log of every command you ran and every policy failure in
`RUNLOG.md`.
