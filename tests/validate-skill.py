#!/usr/bin/env python3
"""Validates every skills/*/SKILL.md against the Agent Skills spec and checks that
the files it references exist. Exit 1 on the first list of problems."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
problems: list[str] = []

for skill_md in sorted(ROOT.glob("skills/*/SKILL.md")):
    skill = skill_md.parent
    text = skill_md.read_text()
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not match:
        problems.append(f"{skill_md}: missing frontmatter")
        continue
    front = match.group(1)
    fields = dict(re.findall(r"^([a-z-]+):\s*(.*)$", front, re.M))
    name = fields.get("name", "")
    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name) or len(name) > 64:
        problems.append(f"{skill_md}: invalid name {name!r}")
    if name != skill.name:
        problems.append(f"{skill_md}: name {name!r} does not match folder {skill.name!r}")
    description = fields.get("description", "")
    if not 1 <= len(description) <= 1024:
        problems.append(f"{skill_md}: description length {len(description)} out of 1–1024")
    if "compatibility" in fields and len(fields["compatibility"]) > 500:
        problems.append(f"{skill_md}: compatibility over 500 chars")
    lines = text.count("\n") + 1
    if lines > 500:
        problems.append(f"{skill_md}: {lines} lines, spec recommends under 500")
    body = text[match.end():]
    for ref in sorted(set(re.findall(r"`((?:references|scripts|assets)/[A-Za-z0-9_./-]+)`", body))):
        target = skill / ref
        if "<" in ref or ref.endswith("/"):
            continue
        if not target.exists() and not any(skill.glob(ref.replace("<lens>", "*"))):
            problems.append(f"{skill_md}: references {ref} which does not exist")
    for script in sorted(skill.glob("scripts/*.sh")):
        if not script.stat().st_mode & 0o111:
            problems.append(f"{script}: not executable")

if problems:
    print("\n".join(problems))
    sys.exit(1)
print(f"validate-skill: ok ({len(list(ROOT.glob('skills/*/SKILL.md')))} skill)")
