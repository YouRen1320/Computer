SOURCE = '''
API_KEY = "sk-hard-coded-example"
def ask(client, prompt):
    estimated_tokens = len(prompt)
    try:
        return client.create(input=prompt)
    except RateLimitError:
        return ""
'''


def test_no_literal_secret() -> None:
    assert "sk-hard-coded" not in SOURCE


def test_model_is_explicit() -> None:
    assert "model=" in SOURCE


def test_usage_not_character_count() -> None:
    assert "len(prompt)" not in SOURCE


def test_429_is_not_an_answer() -> None:
    assert 'return ""' not in SOURCE
