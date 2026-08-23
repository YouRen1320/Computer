def fits_context(text: str, context_limit_tokens: int) -> bool:
    # 练习缺口：字符数被错误地当成目标Tokenizer的token数。
    return len(text) <= context_limit_tokens
