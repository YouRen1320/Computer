def fits_context(recorded_token_count: int, context_limit_tokens: int, output_reserve: int, overhead: int) -> bool:
    if min(recorded_token_count, context_limit_tokens, output_reserve, overhead) < 0:
        raise ValueError("token counts must be non-negative")
    return recorded_token_count + output_reserve + overhead <= context_limit_tokens
