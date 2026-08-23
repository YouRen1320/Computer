"""Locked negative fixture: these assignments must remain static type errors."""

from model import PrioritySuggestion, ReviewQueue


wrong_model: PrioritySuggestion = ReviewQueue()
PrioritySuggestion(order_id="WO-9", level="high")
