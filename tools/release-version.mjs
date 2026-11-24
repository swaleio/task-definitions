#!/usr/bin/env node
// A task definition's version is the version of the tool it runs, read from
// the tag of the image it pins: the `# <image>:<tag>` comment directly above
// exec.image. Releasing the definition again on the same tool version adds
// -r1, -r2, and so on.
//
//   node tools/release-version.mjs git-clone          the next version to release
//   node tools/release-version.mjs git-clone 2.54.0   exits 1 unless it is a valid one
//
// The next version counts the release tags git knows, so fetch tags first.

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// The comment and the image line Renovate reads, in the same shape.
const IMAGE_RE = /#\s*([^\s:@]+(?:\/[^\s:@]+)+):([^\s@]+)\s*\n\s*image:\s*([^\s@]+)@sha256:[a-f0-9]{64}/;

// The pinned image: the repository and tag in the comment, and the repository
// on the image line, which must be the same one.
export function pinnedImage(text) {
  const match = IMAGE_RE.exec(text);
  return match ? { repository: match[1], tag: match[2], imageRepository: match[3] } : null;
}

// The tool's version in an image tag: a dotted version at its start, with an
// optional leading `v` (`v0.25.0-cu129-ubuntu2404`), or llama.cpp's build
// number (`full-b9976`). Anything after the version names a variant or, on a
// swale-built image, a rebuild (`2.54.0-r1`).
export function toolVersion(tag) {
  const build = /^full-(b\d+)$/.exec(tag);
  if (build) {
    return build[1];
  }
  const version = /^v?(\d+(?:\.\d+)+)(?:-|$)/.exec(tag);
  return version ? version[1] : null;
}

export function isReleaseVersion(version, tool) {
  return version === tool || new RegExp(`^${tool.replaceAll(".", "\\.")}-r[1-9][0-9]*$`).test(version);
}

function nextVersion(name, tool, root) {
  const tags = execFileSync("git", ["tag", "--list", `${name}/${tool}`, `${name}/${tool}-r*`], {
    cwd: root,
    encoding: "utf8",
  })
    .split("\n")
    .map((tag) => tag.slice(name.length + 1))
    .filter((version) => version && isReleaseVersion(version, tool));
  if (tags.length === 0) {
    return tool;
  }
  const highest = Math.max(...tags.map((version) => (version === tool ? 0 : Number(version.split("-r").pop()))));
  return `${tool}-r${highest + 1}`;
}

function main([name, version]) {
  if (!name) {
    console.error("Usage: release-version.mjs <task-name> [<version>]");
    return 1;
  }
  const root = dirname(dirname(fileURLToPath(import.meta.url)));
  let text;
  try {
    text = readFileSync(join(root, "tasks", name, "task.md"), "utf8");
  } catch {
    console.error(`::error::tasks/${name}/task.md does not exist`);
    return 1;
  }
  const image = pinnedImage(text);
  const tool = image && toolVersion(image.tag);
  if (!tool) {
    console.error(`::error::tasks/${name}/task.md pins no image tag a version can be read from`);
    return 1;
  }
  if (version === undefined) {
    console.log(nextVersion(name, tool, root));
    return 0;
  }
  if (!isReleaseVersion(version, tool)) {
    console.error(
      `::error::${name}/${version} does not match the tool version its image tag names: ` +
        `release it as ${name}/${tool}, or ${name}/${tool}-r<N> to release it again on that version`,
    );
    return 1;
  }
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(main(process.argv.slice(2)));
}
