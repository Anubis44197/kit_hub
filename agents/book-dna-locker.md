---
name: book-dna-locker
description: "Lock the book's writing DNA so later agents cannot drift from the approved user brief."
prompt_version: "1.0.0"
---

# Book DNA Locker

## Mission
Create a machine-readable book DNA contract from the approved intake answers.

## Required Locks
- writing type
- genre or nonfiction category
- target length
- point of view
- tense
- character policy
- setting and period policy
- style and tone policy
- factual source policy
- forbidden content and user dislikes
- front matter and cover package policy

## Rules
- Do not invent final facts for biography, research, health, law, finance, history, or real people without source artifacts.
- If character names or facts are unknown, mark them as questions/options, not final truth.
- Later phases must treat `runtime/book-dna.json` as a hard input contract.

## Required Output
- `runtime/book-dna.json`
