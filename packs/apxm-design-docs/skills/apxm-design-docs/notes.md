# apxm-design-docs — entry flow design

The skill is a *prose-discipline gate*. It reviews edits to
`docs/design/` for the two failure modes that have actually shipped:
overclaim (present-tense prose about behaviour that is not yet wired)
and citation drift (factual claims with no anchor to shipped code).

## Probe sequence

1. **Diff parse**. Read the proposed edit relative to the current file
   on disk. Identify added sentences, modified sentences, and section
   headers.
2. **Tense + status check**. Every present-tense factual claim about
   runtime/compiler/server behaviour must have a citation. Sections
   that describe aspirational or in-flight work must carry an
   explicit label (e.g. a `Status: design` admonition); otherwise the
   skill flags them as overclaim candidates.
3. **Citation resolution**. For each cited path or commit, verify the
   target exists on the current branch. Stale citations are flagged.
4. **Cross-doc consistency**. If the edit changes a claim that other
   docs in `docs/design/` repeat, the skill surfaces those neighbours
   so the operator can fan out the correction.

## Output schema

```json
{
  "edit_summary": "...",
  "claims": [
    {"sentence": "...", "citation": "crates/.../file.rs:42", "status": "verified"},
    {"sentence": "...", "citation": null, "status": "needs-citation"},
    {"sentence": "...", "citation": "external/vllm/...", "status": "aspirational-but-unlabelled"}
  ],
  "stale_citations": ["docs/design/old.md#L17 → crates/removed/path.rs"],
  "fanout_candidates": ["docs/design/neighbour.md"]
}
```

## Why no LLM call in the entry flow

Citation verification is deterministic — a path either exists at the
cited line range or it does not. Tense classification could use an
LLM, but a sentence-level heuristic ("present-tense indicative verb
+ subsystem noun") catches the recorded failure cases without taxing
the calling agent's budget.

## Hard contracts surfaced in the output

- Every factual claim about shipped behaviour cites a path or commit.
- Aspirational sections are labelled explicitly, not implicitly.
- The skill *does not write the doc edit* — it gates the operator's
  edit and surfaces the failure modes; the operator applies the
  corrections.
