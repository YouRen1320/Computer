# Model API, prompt and usage exercise

Edit `exercise.py` to pass the model explicitly, retain prompt/request identity,
validate non-negative provider usage (`cached <= input` and documented total),
and preserve 429 as an error channel. The fixture uses only the obvious
`TEST_ONLY_CREDENTIAL` text—no provider-key-looking string. Exit states are
exact starter 41, completed 0, and partial/unknown/infrastructure 43.
