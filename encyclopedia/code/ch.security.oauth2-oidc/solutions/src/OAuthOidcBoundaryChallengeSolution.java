/** Private reference for OAuth/OIDC transaction and credential boundaries. */
public final class OAuthOidcBoundaryChallengeSolution {
    enum TokenKind { ACCESS, ID, REFRESH }
    enum Destination { RESOURCE_SERVER, CLIENT_LOGIN, TOKEN_ENDPOINT }

    private OAuthOidcBoundaryChallengeSolution() { }

    public static void main(String[] args) {
        String state = "SYNTHETIC-STATE-A";
        String nonce = "SYNTHETIC-NONCE-A";
        String redirect = "https://factorycare.example.test/login/oauth2/code/factorycare";
        String challenge = "SYNTHETIC-S256-CHALLENGE-A";

        require(validState(state, state), "VALID_STATE_REJECTED");
        require(!validState("", state), "MISSING_STATE_ACCEPTED");
        require(validNonce(nonce, nonce), "VALID_NONCE_REJECTED");
        require(!validNonce("SYNTHETIC-NONCE-B", nonce), "WRONG_NONCE_ACCEPTED");
        require(exactRedirect(redirect, redirect), "VALID_REDIRECT_REJECTED");
        require(!exactRedirect("https://factorycare.example.test.attacker.test/callback", redirect),
                "WIDE_REDIRECT_ACCEPTED");
        require(pkceMatches(challenge, challenge), "VALID_PKCE_REJECTED");
        require(!pkceMatches("SYNTHETIC-S256-CHALLENGE-B", challenge), "WRONG_VERIFIER_ACCEPTED");
        require(tokenPurpose(TokenKind.ACCESS, Destination.RESOURCE_SERVER), "ACCESS_TOKEN_REJECTED_BY_API");
        require(!tokenPurpose(TokenKind.ID, Destination.RESOURCE_SERVER), "ID_TOKEN_ACCEPTED_BY_API");
        require(refreshKeptOutOfFrontend(false), "SAFE_REFRESH_BOUNDARY_REJECTED");
        require(!refreshKeptOutOfFrontend(true), "REFRESH_TOKEN_SENT_TO_FRONTEND");
        require(publicClientCredentialSafe(false), "SAFE_PUBLIC_CLIENT_REJECTED");
        require(!publicClientCredentialSafe(true), "PUBLIC_CLIENT_STATIC_SECRET_ACCEPTED");

        System.out.println("challenge_valid=true state=true nonce=true redirect=true pkce=true token_purpose=true refresh=true public_client=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean validState(String returned, String expected) {
        return returned != null && !returned.isBlank() && returned.equals(expected);
    }

    static boolean validNonce(String idTokenNonce, String expected) {
        return idTokenNonce != null && !idTokenNonce.isBlank() && idTokenNonce.equals(expected);
    }

    static boolean exactRedirect(String returned, String registered) {
        return registered != null && registered.equals(returned);
    }

    static boolean pkceMatches(String derivedChallenge, String expectedChallenge) {
        return expectedChallenge != null && expectedChallenge.equals(derivedChallenge);
    }

    static boolean tokenPurpose(TokenKind token, Destination destination) {
        return switch (token) {
            case ACCESS -> destination == Destination.RESOURCE_SERVER;
            case ID -> destination == Destination.CLIENT_LOGIN;
            case REFRESH -> destination == Destination.TOKEN_ENDPOINT;
        };
    }

    static boolean refreshKeptOutOfFrontend(boolean frontendContainsRefreshToken) {
        return !frontendContainsRefreshToken;
    }

    static boolean publicClientCredentialSafe(boolean containsStaticCredential) {
        return !containsStaticCredential;
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
