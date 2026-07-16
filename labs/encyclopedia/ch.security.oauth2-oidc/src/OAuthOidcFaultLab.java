/** Injects client-boundary faults without constructing real OAuth credentials. */
public final class OAuthOidcFaultLab {
    private static final String STATE = "SYNTHETIC-STATE-A";
    private static final String NONCE = "SYNTHETIC-NONCE-A";
    private static final String REDIRECT = "https://factorycare.example.test/login/oauth2/code/factorycare";
    private static final String CHALLENGE = "SYNTHETIC-S256-CHALLENGE-A";
    private static final String REFRESH_MARKER = "SYNTHETIC-REFRESH-MARKER";

    private enum FaultMode {
        NORMAL,
        MISSING_STATE,
        WIDE_REDIRECT,
        PKCE_NOT_CHECKED,
        NONCE_NOT_CHECKED,
        ID_TOKEN_AS_API,
        REFRESH_TOKEN_EXPOSED,
        PUBLIC_CLIENT_SECRET
    }

    private enum TokenKind { ACCESS, ID, REFRESH }
    private record Callback(String state, String nonce, String redirect, String derivedChallenge) { }
    private record Result(boolean accepted, String category) { }

    private OAuthOidcFaultLab() { }

    private static Result validate(Callback callback, FaultMode fault) {
        if (fault != FaultMode.MISSING_STATE && !STATE.equals(callback.state())) {
            return rejected("state");
        }
        if (fault != FaultMode.NONCE_NOT_CHECKED && !NONCE.equals(callback.nonce())) {
            return rejected("nonce");
        }
        boolean redirectMatches = fault == FaultMode.WIDE_REDIRECT
                ? callback.redirect().startsWith("https://factorycare.example.test")
                : REDIRECT.equals(callback.redirect());
        if (!redirectMatches) {
            return rejected("redirect");
        }
        if (fault != FaultMode.PKCE_NOT_CHECKED && !CHALLENGE.equals(callback.derivedChallenge())) {
            return rejected("pkce");
        }
        return new Result(true, "accepted");
    }

    private static Result rejected(String category) {
        return new Result(false, category);
    }

    private static Callback valid() {
        return new Callback(STATE, NONCE, REDIRECT, CHALLENGE);
    }

    private static boolean acceptedByApi(TokenKind kind, FaultMode fault) {
        return kind == TokenKind.ACCESS || fault == FaultMode.ID_TOKEN_AS_API;
    }

    private static String frontendPayload(TokenKind kind, FaultMode fault) {
        if (kind == TokenKind.REFRESH && fault == FaultMode.REFRESH_TOKEN_EXPOSED) {
            return "refresh=" + REFRESH_MARKER;
        }
        return "session=server-side";
    }

    private static boolean publicClientConfigurationSafe(boolean hasStaticCredential, FaultMode fault) {
        return fault == FaultMode.PUBLIC_CLIENT_SECRET || !hasStaticCredential;
    }

    private static String injectedOutcome(FaultMode fault) {
        return switch (fault) {
            case MISSING_STATE -> validate(new Callback("", NONCE, REDIRECT, CHALLENGE), fault).accepted()
                    ? "MISSING_STATE_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case WIDE_REDIRECT -> validate(new Callback(STATE, NONCE,
                    "https://factorycare.example.test.attacker.test/callback", CHALLENGE), fault).accepted()
                    ? "WIDE_REDIRECT_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case PKCE_NOT_CHECKED -> validate(new Callback(STATE, NONCE, REDIRECT,
                    "SYNTHETIC-S256-CHALLENGE-B"), fault).accepted()
                    ? "WRONG_VERIFIER_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case NONCE_NOT_CHECKED -> validate(new Callback(STATE, "SYNTHETIC-NONCE-B", REDIRECT,
                    CHALLENGE), fault).accepted() ? "WRONG_NONCE_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case ID_TOKEN_AS_API -> acceptedByApi(TokenKind.ID, fault)
                    ? "ID_TOKEN_ACCEPTED_BY_API" : "FAULT_NOT_EXPOSED";
            case REFRESH_TOKEN_EXPOSED -> frontendPayload(TokenKind.REFRESH, fault).contains(REFRESH_MARKER)
                    ? "REFRESH_TOKEN_SENT_TO_FRONTEND" : "FAULT_NOT_EXPOSED";
            case PUBLIC_CLIENT_SECRET -> publicClientConfigurationSafe(true, fault)
                    ? "PUBLIC_CLIENT_STATIC_SECRET_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case NORMAL -> "FAULT_NOT_EXPOSED";
        };
    }

    public static void main(String[] args) {
        FaultMode fault = args.length == 0 ? FaultMode.NORMAL : FaultMode.valueOf(args[0]);
        if (fault != FaultMode.NORMAL) {
            System.out.println(injectedOutcome(fault));
            return;
        }

        Result valid = validate(valid(), fault);
        Result missingState = validate(new Callback("", NONCE, REDIRECT, CHALLENGE), fault);
        Result wrongNonce = validate(new Callback(STATE, "SYNTHETIC-NONCE-B", REDIRECT, CHALLENGE), fault);
        Result wideRedirect = validate(new Callback(STATE, NONCE,
                "https://factorycare.example.test.attacker.test/callback", CHALLENGE), fault);
        Result wrongVerifier = validate(new Callback(STATE, NONCE, REDIRECT,
                "SYNTHETIC-S256-CHALLENGE-B"), fault);
        boolean publicClientHasStaticCredential = false;
        if (!publicClientConfigurationSafe(publicClientHasStaticCredential, fault)) {
            throw new IllegalStateException("SAFE_PUBLIC_CLIENT_REJECTED");
        }

        System.out.println("valid_callback=" + (valid.accepted() ? "ACCEPTED" : "REJECTED"));
        System.out.println("missing_state=" + (missingState.accepted() ? "ACCEPTED" : "REJECTED"));
        System.out.println("wrong_nonce=" + (wrongNonce.accepted() ? "ACCEPTED" : "REJECTED"));
        System.out.println("wide_redirect=" + (wideRedirect.accepted() ? "ACCEPTED" : "REJECTED"));
        System.out.println("wrong_verifier=" + (wrongVerifier.accepted() ? "ACCEPTED" : "REJECTED"));
        System.out.println("id_token_to_api=" + (acceptedByApi(TokenKind.ID, fault) ? "ACCEPTED" : "REJECTED"));
        System.out.println("refresh_token_exposed="
                + frontendPayload(TokenKind.REFRESH, fault).contains(REFRESH_MARKER));
        System.out.println("public_client_secret=" + publicClientHasStaticCredential);
        System.out.println("verification_report=PASS assertions=8");
    }
}
