---
name: design
description: "Route ambiguous design requests to propose, design-big, design-small, or integrated sequence."
prompt_version: "1.0.0"
---

# Design Router Skill

## Purpose
Route user intent to the right design stage.

## Routing Rules
- Idea generation request -> `propose`
- Big architecture request -> `design-big`
- 25-episode detail request -> `design-small`
- Full end-to-end design request -> `design-big` then `design-small`

## Behavior
- Ask scope clarification when request is ambiguous.
- Preserve stage ordering guarantees.
