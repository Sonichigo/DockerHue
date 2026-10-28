# dockerhue

Polyglot colour containers (Go, Python, Node, and Rust)
behind a tiny gateway that paints each container's hue. Every Dockerfile has
to pass an OPA/conftest policy gate before anything builds.

Built to run **inside a Docker Sandbox**: an AI agent gets its own microVM
with its own Docker Engine, builds and runs the whole stack, and has to
satisfy the policy, all without touching your host Docker daemon.

```sh
services/
  go/ python/ node/ rust/   colour services, each answers GET / with {lang,color,host}
  web/                gateway on :8080, renders tiles, /api returns JSON
policy/dockerfile.rego
compose.yaml
Makefile              make policy | make up | make status | make down
AGENT_TASK.md         prompt to paste into the sandboxed agent
```

## Policy rules

| Rule   | Denies                                              |
|--------|-----------------------------------------------------|
| HUE001 | base image with `:latest` or no tag                 |
| HUE002 | final stage with no `USER`, or `USER root` / `0`    |
| HUE003 | `ADD` (use `COPY`)                                  |
| HUE004 | missing `LABEL dockerhue.lang=<language>`           |

All four services pass every rule. The Rust service started out in
`challenge/rust/` with a Dockerfile that broke all four on purpose; the agent
moved it to `services/rust/` and fixed it (see `RUNLOG.md`). To rerun that
exercise, restore the starter commit.

## Run it in a Docker Sandbox (2-hour runbook)

### 0:00 – 0:15 · Install and sign in

macOS (Apple silicon, Sonoma 14+):

```sh
brew trust docker/tap
brew install docker/tap/sbx
sbx login
```

Ubuntu 24.04+ (needs KVM; add yourself to the `kvm` group first):

```sh
curl -fsSL https://get.docker.com | sudo REPO_ONLY=1 sh
sudo apt install docker-sbx
sbx login
```

Windows 11: `winget install -h Docker.sbx`, then `sbx login`.

### 0:15 – 0:25 · Launch the sandbox

```sh
cd dockerhue
git init && git add -A && git commit -m "dockerhue starter"   # so you can diff what the agent changes
sbx run --name dockerhue --publish 8080:8080 claude
```

When prompted for the network preset, pick **Balanced** (default deny, common
dev registries allowed). Inside the agent, run `/login` if you use a Claude
subscription.

📸 Screenshot: the network-policy prompt and `sbx ls` from a second terminal
(it shows your folder is the only host path the agent can see).

### 0:25 – 1:00 · Let the agent work

Paste the contents of `AGENT_TASK.md` into the agent. Watch for, and capture:

- the first `make policy` failure on the Rust Dockerfile (4 violations, when starting from the starter commit)
- how the agent fixes each one (usually multi-stage build, pinned tags, `COPY`, `USER`)
- the green `make policy` run
- `curl localhost:8080/api` showing four services

Open `http://localhost:8080` on your host to see the tiles.
If the page doesn't load, publish the port on the running sandbox:

```sh
sbx ports dockerhue --publish 8080:8080
```

📸 Screenshot: the four tiles in your browser, and the red → green policy output.

### 1:00 – 1:15 · Prove the walls

From a second terminal on your host:

```sh
docker ps            # your host daemon: none of the dockerhue containers are here
sbx exec -it dockerhue bash -c "docker ps"   # they all live inside the sandbox
sbx policy ls        # the network rules in force
git diff --stat      # everything the agent changed, as an ordinary diff
```

The `curl -sI https://example.org` step in the task shows what the Balanced
network policy does with a host outside the allowlist. Record exactly what
you see; don't assume.

Optional: open the dashboard with `sbx` and use its network panel to show
the blocked connection.

### 1:15 – 2:00 · Write the post

Suggested outline:

1. **Hook:** I gave an agent root on Docker and it still couldn't touch my machine.
2. **Setup:** what dockerhue is; the two walls (sandbox microVM + OPA gate).
3. **Run:** install, `sbx run`, the task prompt.
4. **The interesting part:** the policy failures and how the agent fixed them (paste RUNLOG.md excerpts).
5. **Proof:** host `docker ps` empty vs sandbox `docker ps` full; network policy result; `git diff`.
6. **Takeaway:** sandbox = blast radius for the agent; policy = blast radius for what it ships.

### Clean up

```sh
sbx stop dockerhue
sbx rm dockerhue
```

## Run it without a sandbox

```sh
make up
curl -s localhost:8080/api
make down
```
