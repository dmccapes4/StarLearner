# AndromedaBrainScans — Corpus Inventory

Gathered 10052 segments and 46306 concept occurrences from 11 corpora into one schema and one 384-d MiniLM space.

| corpus | kind | label | segments | Layer-1 states | concepts | sort |
|---|---|---|---|---|---|---|
| `history_b2n` | video | BeginningToNoww — world history (zohg5rx5ptU) | 839 | 839 | 3765 | existing (BeginningToNoww run 2) |
| `six_a` | video | CapricornusSix — six history compilations (run A) | 2724 | 2724 | 12768 | existing (CapricornusSix) |
| `six_b` | video | sixvideos_20261009 — same six videos (run B, replicate) | 2701 | 0 | 12447 | existing (sixvideos_20261009) |
| `mythology` | video | PortalVision mythology (4M-4M4LyUB0) | 278 | 278 | 1979 | to run (03_sort_corpus.py) |
| `sports` | video | PortalVision sports (CPbQ0V4LY6Y) | 385 | 385 | 1670 | to run (03_sort_corpus.py) |
| `warfare` | video | PortalVision warfare (0LxXcKAQ69U) | 281 | 281 | 1529 | to run (03_sort_corpus.py) |
| `childhood` | video | PortalVision childhood (5 videos) | 195 | 195 | 681 | to run (03_sort_corpus.py) |
| `family` | video | PortalVision family / marriage (4 videos) | 84 | 84 | 366 | to run (03_sort_corpus.py) |
| `islam_origin` | video | PortalVision islam_origin (2 videos) | 45 | 45 | 329 | to run (03_sort_corpus.py) |
| `leper_king` | video | PortalVision leper_king — Baldwin IV (2 videos) | 172 | 172 | 765 | to run (03_sort_corpus.py) |
| `sacred` | book | Sacred Concepts Atlas — Tanakh (he), Bible WEB (en), Quran (ar) | 2348 | 0 | 10007 | to run (03_sort_corpus.py) |

## Schema

`corpus/segments.jsonl`: `uid, corpus, kind, source_id, seq, start_sec, end_sec, ref, text, layer1`  
`corpus/concepts.jsonl`: `cidx, uid, corpus, kind, source_id, start_sec, concept_name, in_context, understanding, root_language, root_derivation, minted, confidence, weight, origin`  
`corpus/embeddings.npy`: row = `cidx`; weights name 1.0 / in-context 3.0 / understanding 2.0 / root ρ 0.5 (BeginningToNoww formula, re-applied to every corpus so all share one space).

## Notes

- `six_b`: state is provenance (carry/agreement), not Layer-1 observation
- `sacred`: concept registry (806 types) expanded to occurrences via section_concepts; rationale used as in_context; no PIE root field in source — root_language set none_found, ρ not applied
- `six_b` is a replicate of `six_a` (same videos, independent run); keep both, never pool them as if independent samples of different material.
- `history_b2n` Layer-1 states are the adapted atlas records in `PortalVision/data/capricornus/history/history_signalworld.jsonl` (839).
- Ahkyrios (183 vision records, screenshot-based, different schema) is not gathered; it has no segment text to extract concepts from.
- Not gathered (different domain): `~/dev/2OPMD/autoimmune_concepts_atlas` (medical texts). Listed for completeness.
