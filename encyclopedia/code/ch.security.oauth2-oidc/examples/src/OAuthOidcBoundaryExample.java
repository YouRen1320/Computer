/** Models client-side transaction binding without creating protocol credentials. */
public final class OAuthOidcBoundaryExample {
    private static final String STATE = "SYNTHETIC-STATE-A";
    private static final String NONCE = "SYNTHETIC-NONCE-A";
    private static final String REDIRECT = "https://factorycare.example.test/login/oauth2/code/factorycare";
    private static final String CHALLENGE = "SYNTHETIC-S256-CHALLENGE-A";

    private enum TokenKind { ACCESS, ID, REFRESH }
    private enum Destination { RESOURCE_SERVER, CLIENT_LOGIN, TOKEN_ENDPOINT, FRONTEND }

    private static final class Transaction {
        private boolean consumed;
    }

    private record Callback(String state, String nonce, String redirect, String derivedChallenge) { }
    private record Result(boolean accepted, String category) { }

    private OAuthOidcBoundaryExample() { }

    private static Result validate(Transaction transaction, Callback callback) {
        if (transaction.consumed) {
            return new Result(false, "replay");
        }
        if (!STATE.equals(callback.state())) {
            return new Result(false, "state");
        }
        if (!NONCE.equals(callback.nonce())) {
            return new Result(false, "nonce");
        }
        if (!REDIRECT.equals(callback.redirect())) {
            return new Result(false, "redirect");
        }
        if (!CHALLENGE.equals(callback.derivedChallenge())) {
            return new Result(false, "pkce");
        }
        transaction.consumed = true;
        return new Result(true, "accepted");
    }

    private static Callback validCallback() {
        return new Callback(STATE, NONCE, REDIRECT, CHALLENGE);
    }

    private static boolean tokenAllowedAt(TokenKind token, Destination destination) {
        return switch (token) {
            case ACCESS -> destination == Destination.RESOURCE_SERVER;
            case ID -> destination == Destination.CLIENT_LOGIN;
            case REFRESH -> destination == Destination.TOKEN_ENDPOINT;
        };
    }

    public static void main(String[] args) {
        Transaction acceptedTransaction = new Transaction();
        Result accepted = validate(acceptedTransaction, validCallback());
        Result replay = validate(acceptedTransaction, validCallback());
        Result wrongState = validate(new Transaction(), new Callback("SYNTHETIC-STATE-B", NONCE, REDIRECT, CHALLENGE));
        Result wrongNonce = validate(new Transaction(), new Callback(STATE, "SYNTHETIC-NONCE-B", REDIRECT, CHALLENGE));
        Result wrongRedirect = validate(new Transaction(), new Callback(STATE, NONCE,
                "https://factorycare.example.test/login/oauth2/code/other", CHALLENGE));
        Result wrongPkce = validate(new Transaction(), new Callback(STATE, NONCE, REDIRECT,
                "SYNTHETIC-S256-CHALLENGE-B"));

        System.out.println("callback_accepted=" + accepted.accepted());
        System.out.println("state_mismatch_rejected=" + !wrongState.accepted());
        System.out.println("nonce_mismatch_rejected=" + !wrongNonce.accepted());
        System.out.println("redirect_mismatch_rejected=" + !wrongRedirect.accepted());
        System.out.println("pkce_mismatch_rejected=" + !wrongPkce.accepted());
        System.out.println("callback_replay_rejected=" + !replay.accepted());
        System.out.println("access_token_to_api=" + tokenAllowedAt(TokenKind.ACCESS, Destination.RESOURCE_SERVER));
        System.out.println("id_token_to_api=" + tokenAllowedAt(TokenKind.ID, Destination.RESOURCE_SERVER));
        System.out.println("refresh_token_to_frontend=" + tokenAllowedAt(TokenKind.REFRESH, Destination.FRONTEND));
        System.out.println("public_client_static_secret=false");
        System.out.println("secret_material_printed=false");
    }
}
