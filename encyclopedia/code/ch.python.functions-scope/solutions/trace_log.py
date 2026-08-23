"""Private solution with call-time list creation."""


def append_trace(message, trace=None):
    if trace is None:
        trace = []
    trace.append(message)
    return trace
