# LangChain parity fixture

The “official SDK” is a deterministic local fake with an explicit request
contract. No model provider or online retriever is contacted. The example uses
the installed LangChain Runnable, prompt and parser APIs to prove parity,
configuration propagation, exception identity and cancellation propagation.
