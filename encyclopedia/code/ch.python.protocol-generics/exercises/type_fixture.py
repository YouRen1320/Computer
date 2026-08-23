"""Injection point that must fail until BrokenRepository implements save."""

from exercise import BrokenRepository, PrioritySuggestion, persist


repository = BrokenRepository()
persist(repository, PrioritySuggestion(1, 4))
