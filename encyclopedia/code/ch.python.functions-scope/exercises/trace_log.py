"""Public exercise: the mutable default is intentionally wrong."""


def append_trace(message, trace=[]):
    trace.append(message)
    return trace
