---
name: intake
description: "Interview the user, lock the writing brief, and define layout/front-matter/cover requirements before planning starts."
prompt_version: "1.0.0"
---

# Intake Skill

## Purpose
Prevent the model from writing from a vague prompt. The system must ask questions, propose options when needed, and lock the accepted book brief before `propose`, `design-big`, `create`, `polish`, `rewrite`, or `export`.

## Required Agents
1. `brief-interviewer`
2. `book-dna-locker`
3. `layout-profile-planner`

## Required User Decisions
- writing type: novel, story, novella, essay, biography, memoir, research book, children's book, poetry, or other
- subject/premise
- target reader
- target pages, words, or chapters
- genre/category
- point of view
- tense
- character policy
- setting and period
- style and tone
- factual source policy
- forbidden content
- front matter package
- cover package
- print/layout profile

## Output Contract
- `runtime/book-brief.json`
- `runtime/book-dna.json`
- `runtime/layout-profile.json`
- `runtime/approvals/book-brief-approval.json`

## Hard Gate
`runtime/approvals/book-brief-approval.json` must remain `approved=false` until the user accepts the brief and layout profile. Later phases must fail if the brief approval is missing.
