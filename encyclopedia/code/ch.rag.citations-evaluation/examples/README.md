# Offline evidence contract

This example uses a deterministic generator and a frozen four-case corpus. It does
not call a model provider, measure semantic quality, or establish production RAG
performance. It verifies source IDs, character spans, refusal/conflict behavior,
and separate retrieval/answer/refusal/citation counters. Retrieval is judged
against explicit relevant source IDs. Citation structure and entailment use the
number of citations on actual answers as their denominator; a refusal with no
citation is not silently counted as a valid citation.
