# Metrics, traces and SLO exercise

Edit `exercise.py` to use bounded labels, a user-visible latency good-event
ratio, SLO burn-rate alerting and continuous async trace context. The unchanged
starter is the only failure allowed to return 41; completion returns 0 and any
other failure shape returns 43. The production Prometheus/OTel runtime remains
outside this local contract.
