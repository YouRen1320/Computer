# Nginx/TLS boundary-audit exercise

Edit `audit.py` to reject forwarded-header spoofing, API-to-SPA fallback, an
incomplete certificate chain and broad long-lived caching, while admitting the
scoped safe fixture. The verifier uses the 41/0/43 tri-state contract. Static
text checks do not replace `nginx -t`, a live certificate/hostname check or an
upstream smoke test.
