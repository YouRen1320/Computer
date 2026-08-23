import java.util.List;
import java.util.Set;

/** Private oracle for browser output, CSRF, and server-egress policy predicates. */
public final class InputBoundaryChallengeSolution {
    enum AddressClass { GLOBAL_UNICAST, LOOPBACK, PRIVATE, LINK_LOCAL }

    record Destination(String scheme, String host, int port,
                       boolean hasUserInfo, Set<AddressClass> addresses) { }

    private InputBoundaryChallengeSolution() { }

    public static void main(String[] args) {
        String rendered = encodeHtmlText("<img src=x onerror=syntheticAction()>");
        require(!rendered.contains("<img"), "ACTIVE_MARKUP_REACHED_SINK");
        require(rendered.contains("&lt;img"), "HTML_TEXT_NOT_ENCODED");
        require(safeAttribute("aria-label") && !safeAttribute("onerror"),
                "ATTRIBUTE_ALLOWLIST_BROKEN");

        require(csrfAllowed("https://app.factorycare.example.test", "SYNTHETIC-CSRF"),
                "VALID_CSRF_REJECTED");
        require(!csrfAllowed("https://attacker.example.test", null),
                "CROSS_SITE_WRITE_ACCEPTED");

        Destination allowed = new Destination(
                "https", "manuals.factorycare.example.test", 443, false,
                Set.of(AddressClass.GLOBAL_UNICAST));
        Destination loopback = new Destination(
                "https", "127.0.0.1", 443, false, Set.of(AddressClass.LOOPBACK));
        Destination wrongScheme = new Destination(
                "file", "manuals.factorycare.example.test", -1, false,
                Set.of(AddressClass.GLOBAL_UNICAST));
        require(destinationAllowed(allowed), "ALLOWED_DESTINATION_REJECTED");
        require(!destinationAllowed(loopback), "LOOPBACK_DESTINATION_ACCEPTED");
        require(!destinationAllowed(wrongScheme), "NON_ALLOWED_SCHEME_ACCEPTED");

        require(!redirectAllowed(List.of(allowed, loopback)), "REDIRECT_BOUNDARY_BYPASSED");
        require(!bindingStable(
                Set.of(AddressClass.GLOBAL_UNICAST), Set.of(AddressClass.LOOPBACK)),
                "DNS_REBINDING_ACCEPTED");

        System.out.println("challenge_valid=true xss=true csrf=true destination=true redirect=true rebinding=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static String encodeHtmlText(String value) {
        return value.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#x27;");
    }

    static boolean safeAttribute(String name) {
        return Set.of("title", "aria-label", "data-label").contains(name);
    }

    static boolean csrfAllowed(String origin, String token) {
        return "https://app.factorycare.example.test".equals(origin)
                && "SYNTHETIC-CSRF".equals(token);
    }

    static boolean destinationAllowed(Destination destination) {
        return "https".equals(destination.scheme())
                && "manuals.factorycare.example.test".equals(destination.host())
                && destination.port() == 443
                && !destination.hasUserInfo()
                && !destination.addresses().isEmpty()
                && destination.addresses().stream().allMatch(AddressClass.GLOBAL_UNICAST::equals);
    }

    static boolean redirectAllowed(List<Destination> hops) {
        return !hops.isEmpty() && hops.stream().allMatch(InputBoundaryChallengeSolution::destinationAllowed);
    }

    static boolean bindingStable(Set<AddressClass> validated, Set<AddressClass> atConnect) {
        return !validated.isEmpty()
                && validated.equals(atConnect)
                && atConnect.stream().allMatch(AddressClass.GLOBAL_UNICAST::equals);
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
