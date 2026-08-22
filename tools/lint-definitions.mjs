#!/usr/bin/env node
// Validate task-definition files against the Swale platform contract.
//
// Run locally:  npm install && npm run lint
// CI runs this on every pull request and on every release tag.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, dirname, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";
import yaml from "js-yaml";

const NAME_RE = /^[A-Za-z0-9_-]{1,100}$/;
const IDENT_RE = /^[a-z0-9_]+$/; // snake_case identifiers
const DIGEST_RE = /@sha256:[0-9a-f]{64}$/;
const ENV_NAME_RE = /^[A-Za-z_][A-Za-z0-9_]*$/;
const ENV_RESERVED_PREFIXES = ["WORKFLOW_", "INPUT_"];
const DESCRIPTION_MAX_LENGTH = 100;
const MAX_FILE_BYTES = 1024 * 1024;

const TOP_KEYS = new Set(["name", "description", "inputs", "outputs", "exec"]);
const EXEC_KEYS = new Set(["image", "args", "env"]);
const INPUT_KEYS = new Set(["description", "required", "default"]);
const OUTPUT_KEYS = new Set(["description"]);

const isMapping = (value) =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const unknownKeys = (value, allowed) =>
  Object.keys(value)
    .filter((key) => !allowed.has(key))
    .sort();

function splitFrontmatter(text) {
  if (!text.startsWith("---")) {
    return [null, null];
  }
  const end = text.indexOf("\n---", 3);
  if (end === -1) {
    return [null, null];
  }
  const frontmatter = text.slice(3, end).replace(/^\n+/, "");
  const body = text.slice(end + 4).replace(/^[\n\r]+/, "");
  return [frontmatter, body];
}

function lintFile(root, path) {
  const errors = [];
  const rel = relative(root, path).split(sep).join("/");

  const parts = rel.split("/");
  if (parts.length !== 3 || parts[0] !== "tasks" || parts[2] !== "task.md") {
    errors.push(`${rel}: must live at tasks/<name>/task.md (versions are git tags '<name>/<version>')`);
    return errors;
  }
  const name = parts[1];

  if (!NAME_RE.test(name)) {
    errors.push(`${rel}: task name '${name}' must match ${NAME_RE.source} (no dots)`);
  }

  const text = readFileSync(path, "utf8");
  if (Buffer.byteLength(text, "utf8") > MAX_FILE_BYTES) {
    errors.push(`${rel}: file exceeds 1 MiB`);
  }

  const [frontmatter, body] = splitFrontmatter(text);
  if (frontmatter === null) {
    errors.push(`${rel}: missing YAML frontmatter starting at byte 0`);
    return errors;
  }
  if (!body) {
    errors.push(`${rel}: body must be non-empty`);
  }

  let data;
  try {
    data = yaml.load(frontmatter);
  } catch (error) {
    errors.push(`${rel}: frontmatter is not valid YAML: ${error.message}`);
    return errors;
  }
  if (!isMapping(data)) {
    errors.push(`${rel}: frontmatter must be a mapping`);
    return errors;
  }

  const unknownTop = unknownKeys(data, TOP_KEYS);
  if (unknownTop.length > 0) {
    errors.push(`${rel}: unknown top-level keys: ${JSON.stringify(unknownTop)}`);
  }

  const description = data.description;
  if (typeof description !== "string" || description.trim() === "") {
    errors.push(`${rel}: description is required and must be a non-empty string`);
  } else if (description.length > DESCRIPTION_MAX_LENGTH) {
    errors.push(
      `${rel}: description must be at most ${DESCRIPTION_MAX_LENGTH} characters ` +
        `(is ${description.length}) — the platform rejects longer descriptions on import`,
    );
  }

  const execBlock = data.exec;
  if (!isMapping(execBlock)) {
    errors.push(`${rel}: 'exec' is required and must be a mapping`);
  } else {
    const unknownExec = unknownKeys(execBlock, EXEC_KEYS);
    if (unknownExec.length > 0) {
      errors.push(`${rel}: unknown exec keys: ${JSON.stringify(unknownExec)}`);
    }

    const image = execBlock.image;
    if (typeof image !== "string" || image.trim() === "") {
      errors.push(`${rel}: exec.image is required and must be a non-empty string`);
    } else if (!DIGEST_RE.test(image)) {
      errors.push(`${rel}: exec.image must be digest-pinned (…@sha256:<64 hex>): '${image}'`);
    }

    if (execBlock.args !== undefined && !Array.isArray(execBlock.args)) {
      errors.push(`${rel}: exec.args must be a list of strings`);
    }

    const env = execBlock.env;
    if (env !== undefined) {
      if (!isMapping(env)) {
        errors.push(`${rel}: exec.env must be a mapping`);
      } else {
        for (const varName of Object.keys(env)) {
          if (!ENV_NAME_RE.test(varName)) {
            errors.push(`${rel}: exec.env name '${varName}' must match ${ENV_NAME_RE.source}`);
          }
          if (ENV_RESERVED_PREFIXES.some((prefix) => varName.startsWith(prefix))) {
            errors.push(`${rel}: exec.env name '${varName}' uses a reserved prefix (WORKFLOW_/INPUT_)`);
          }
        }
      }
    }
  }

  for (const [section, allowed] of [
    ["inputs", INPUT_KEYS],
    ["outputs", OUTPUT_KEYS],
  ]) {
    const block = data[section];
    if (block === undefined || block === null) {
      continue;
    }
    if (!isMapping(block)) {
      errors.push(`${rel}: '${section}' must be a mapping`);
      continue;
    }
    for (const [ident, spec] of Object.entries(block)) {
      if (!IDENT_RE.test(ident)) {
        errors.push(`${rel}: ${section} identifier '${ident}' must be snake_case (${IDENT_RE.source})`);
      }
      if (spec !== null && spec !== undefined && !isMapping(spec)) {
        errors.push(`${rel}: ${section}.${ident} must be a mapping or empty`);
        continue;
      }
      if (isMapping(spec)) {
        const unknownField = unknownKeys(spec, allowed);
        if (unknownField.length > 0) {
          errors.push(`${rel}: ${section}.${ident} has unknown keys: ${JSON.stringify(unknownField)}`);
        }
      }
    }
  }

  return errors;
}

function findMarkdown(directory) {
  const found = [];
  for (const entry of readdirSync(directory)) {
    const full = join(directory, entry);
    if (statSync(full).isDirectory()) {
      found.push(...findMarkdown(full));
    } else if (entry.endsWith(".md")) {
      found.push(full);
    }
  }
  return found.sort();
}

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const files = findMarkdown(join(root, "tasks"));

if (files.length === 0) {
  console.log("No task definitions found under tasks/.");
  process.exit(0);
}

const allErrors = files.flatMap((path) => lintFile(root, path));

if (allErrors.length > 0) {
  for (const error of allErrors) {
    console.log(`::error::${error}`);
  }
  console.log(`\n${allErrors.length} problem(s) in ${files.length} file(s).`);
  process.exit(1);
}

console.log(`OK: ${files.length} task definition(s) valid.`);
