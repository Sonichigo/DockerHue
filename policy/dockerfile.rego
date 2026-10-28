package main

import rego.v1

# dockerhue policy gate: every service Dockerfile must pass these rules
# before `make up` is allowed to build or run anything.

# Names declared with `FROM ... AS <name>` are build stages, not images.
stage_aliases contains lower(instr.Value[2]) if {
	some instr in input
	instr.Cmd == "from"
	count(instr.Value) >= 3
	lower(instr.Value[1]) == "as"
}

from_images contains instr.Value[0] if {
	some instr in input
	instr.Cmd == "from"
}

# Rule 1: base images must be pinned (no :latest, no missing tag).
deny contains msg if {
	some image in from_images
	not lower(image) in stage_aliases
	image != "scratch"
	not contains(image, "@sha256:")
	not has_tag(image)
	msg := sprintf("HUE001: base image '%s' has no tag; pin a version", [image])
}

deny contains msg if {
	some image in from_images
	endswith(lower(image), ":latest")
	msg := sprintf("HUE001: base image '%s' uses :latest; pin a version", [image])
}

has_tag(image) if {
	parts := split(image, "/")
	contains(parts[count(parts) - 1], ":")
}

# Rule 2: the final stage must switch to a non-root user.
final_stage := max({instr.Stage | some instr in input})

final_users := [instr.Value[0] |
	some instr in input
	instr.Cmd == "user"
	instr.Stage == final_stage
]

deny contains "HUE002: final stage never sets USER; containers must not run as root" if {
	count(final_users) == 0
}

deny contains msg if {
	count(final_users) > 0
	last := final_users[count(final_users) - 1]
	split(last, ":")[0] in {"root", "0"}
	msg := sprintf("HUE002: final USER is '%s'; use a non-root user", [last])
}

# Rule 3: ADD hides remote fetches and archive extraction; use COPY.
deny contains "HUE003: use COPY instead of ADD" if {
	some instr in input
	instr.Cmd == "add"
}

# Rule 4: every image must declare which language/colour it is.
deny contains "HUE004: missing LABEL dockerhue.lang=<language>" if {
	not has_lang_label
}

has_lang_label if {
	some instr in input
	instr.Cmd == "label"
	some i
	instr.Value[i] == "dockerhue.lang"
}
