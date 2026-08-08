#!/usr/bin/env node
/**
 * Computes the "what is currently published" marker for the landing site.
 *
 * The site is a static export: story pages are baked in at build time, so a
 * scheduled rebuild only accomplishes something when either the story data or
 * the landing source has changed since the last deploy. This script reduces
 * both to a pair of hashes:
 *
 *   content=<sha256 of every rendered daily_stories field>
 *   source=<git ids for landing/ and firebase.json>
 *
 * `npm run build` writes the marker into `out/deploy-marker.txt`, so the live
 * site always advertises what it was built from. The Deploy Landing workflow
 * recomputes it before a scheduled run and skips the build when it matches
 * what is already live.
 *
 * Usage:
 *   node scripts/deploy-marker.mjs                     # print to stdout
 *   node scripts/deploy-marker.mjs --write out/deploy-marker.txt
 *
 * Deliberately dependency-free (node: builtins + fetch) so the workflow's
 * check job can run it without `npm ci`.
 */
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { STORY_COLUMNS } from "../src/lib/storyColumns.mjs";

const LANDING_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// PostgREST caps a single response (Supabase defaults to 1000 rows), so page
// through the table rather than silently hashing only the first window.
const PAGE_SIZE = 1000;

// Hash separators. Control characters, because `JSON.stringify` always escapes
// them — no field value can forge a boundary and make two different datasets
// hash alike.
const FIELD_SEP = String.fromCharCode(0);
const ROW_SEP = String.fromCharCode(1);

/// Fetches every story row the anon key can see, oldest first.
///
/// Uses the anon key on purpose: RLS hides future-dated rows from it, which is
/// exactly the set `generateStaticParams` will render. A service-role read
/// would see unpublished rows and churn the hash for pages that never ship.
async function fetchStoryRows(url, key) {
  const base = url.replace(/\/+$/, "");
  const query = new URLSearchParams({
    select: STORY_COLUMNS.join(","),
    order: "publish_date.asc,language.asc",
  });
  const rows = [];
  for (let offset = 0; ; offset += PAGE_SIZE) {
    const res = await fetch(`${base}/rest/v1/daily_stories?${query}`, {
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        Accept: "application/json",
        Range: `${offset}-${offset + PAGE_SIZE - 1}`,
      },
    });
    if (!res.ok) {
      throw new Error(
        `Supabase read failed (${res.status}): ${await res.text()}`,
      );
    }
    const page = await res.json();
    rows.push(...page);
    if (page.length < PAGE_SIZE) return rows;
  }
}

/// Hashes the rows field by field in a fixed column order, so the digest does
/// not depend on JSON key ordering from PostgREST.
function hashRows(rows) {
  const hash = createHash("sha256");
  for (const row of rows) {
    for (const column of STORY_COLUMNS) {
      hash.update(JSON.stringify(row[column] ?? null));
      hash.update(FIELD_SEP);
    }
    hash.update(ROW_SEP);
  }
  return hash.digest("hex");
}

/// Git object ids for everything that shapes the deployed site: the `landing/`
/// tree (the source that renders it) and the `firebase.json` blob (hosting
/// headers, redirects and the public dir). Either one changing must produce a
/// new deploy, so both go in the marker.
///
/// Returns "unknown" outside a git checkout, which reads as "not equal to
/// anything" downstream and therefore forces a rebuild.
function sourceSha() {
  try {
    return execFileSync(
      "git",
      ["rev-parse", "HEAD:landing", "HEAD:firebase.json"],
      {
        cwd: LANDING_DIR,
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
      },
    )
      .trim()
      .split("\n")
      .join("-");
  } catch {
    return "unknown";
  }
}

async function main() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_ANON_KEY;
  if (!url || !key) {
    throw new Error(
      "SUPABASE_URL and SUPABASE_ANON_KEY must be set to compute the marker",
    );
  }
  const rows = await fetchStoryRows(url, key);
  const marker = `content=${hashRows(rows)}\nsource=${sourceSha()}\n`;

  const writeFlag = process.argv.indexOf("--write");
  if (writeFlag !== -1) {
    const target = process.argv[writeFlag + 1];
    if (!target) throw new Error("--write requires a path");
    const path = resolve(LANDING_DIR, target);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, marker);
    process.stderr.write(`Wrote ${path} (${rows.length} story rows)\n`);
  }
  process.stdout.write(marker);
}

await main();
