# Private solution: modeling and narrowing

The solution starts from `unknown`, checks a plain non-null record and own fields, validates every WorkOrder field, handles `cancelled`, and preserves the `never` exhaustiveness boundary.

Run:

    ./verify.sh
