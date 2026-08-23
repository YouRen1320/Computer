import java.net.URI;
import java.util.List;
import java.util.Set;

/** Offline source-to-sink example with synthetic URLs and fake address classifications. */
public final class UntrustedInputExample {
    enum AddressClass { GLOBAL_UNICAST, LOOPBACK, PRIVATE, LINK_LOCAL }

    record Destination(URI uri, Set<AddressClass> addresses) { }

    private static final String TRUSTED_ORIGIN = "https://app.factorycare.example.test";
    private static final String EXPECTED_CSRF = "SYNTHETIC-CSRF";
    private static final Set<String> ALLOWED_HOSTS = Set.of("manuals.factorycare.example.test");
    private static final Set<String> SAFE_ATTRIBUTES = Set.of("title", "aria-label", "data-label");

    private UntrustedInputExample() { }

    public static void main(String[] args) {
        require(!stateChangeAllowed("https://attacker.example.test", null),
                "CROSS_SITE_WRITE_ACCEPTED");

        String payload = "<img src=x onerror=syntheticAction()>";
        String encoded = encodeHtmlText(payload);
        require(encoded.contains("&lt;img") && !encoded.contains("<img"),
                "ACTIVE_MARKUP_REACHED_TEXT_SINK");
        require(!safeAttribute("onerror") && safeAttribute("aria-label"),
                "DANGEROUS_ATTRIBUTE_ACCEPTED");

        Destination allowed = destination(
                "https://manuals.factorycare.example.test/guides/wo-1",
                AddressClass.GLOBAL_UNICAST);
        Destination loopback = destination("https://127.0.0.1/admin", AddressClass.LOOPBACK);
        Destination nonHttps = destination(
                "http://manuals.factorycare.example.test/guides/wo-1",
                AddressClass.GLOBAL_UNICAST);
        require(destinationAllowed(allowed), "ALLOWED_DESTINATION_REJECTED");
        require(!destinationAllowed(loopback), "LOOPBACK_DESTINATION_ACCEPTED");
        require(!destinationAllowed(nonHttps), "NON_HTTPS_DESTINATION_ACCEPTED");

        Destination redirectToPrivate = destination(
                "https://metadata.factorycare.example.test/latest",
                AddressClass.LINK_LOCAL);
        require(!redirectChainAllowed(List.of(allowed, redirectToPrivate)),
                "REDIRECT_BOUNDARY_BYPASSED");
        require(!bindingStable(Set.of(AddressClass.GLOBAL_UNICAST), Set.of(AddressClass.LOOPBACK)),
                "DNS_REBINDING_ACCEPTED");

        System.out.println("cross_site_write_rejected=true");
        System.out.println("text_rendered_as_data=true");
        System.out.println("dangerous_attribute_rejected=true");
        System.out.println("allowed_https_url=true");
        System.out.println("loopback_rejected=true");
        System.out.println("non_https_rejected=true");
        System.out.println("redirect_private_rejected=true");
        System.out.println("dns_rebinding_rejected=true");
        System.out.println("secret_material_printed=false");
    }

    static String encodeHtmlText(String value) {
        return value.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#x27;");
    }

    static boolean safeAttribute(String name) {
        return SAFE_ATTRIBUTES.contains(name);
    }

    static boolean stateChangeAllowed(String origin, String csrfToken) {
        return TRUSTED_ORIGIN.equals(origin) && EXPECTED_CSRF.equals(csrfToken);
    }

    static boolean destinationAllowed(Destination destination) {
        URI uri = destination.uri();
        int effectivePort = uri.getPort() == -1 ? 443 : uri.getPort();
        return "https".equals(uri.getScheme())
                && uri.getUserInfo() == null
                && ALLOWED_HOSTS.contains(uri.getHost())
                && effectivePort == 443
                && !destination.addresses().isEmpty()
                && destination.addresses().stream().allMatch(AddressClass.GLOBAL_UNICAST::equals);
    }

    static boolean redirectChainAllowed(List<Destination> hops) {
        return !hops.isEmpty() && hops.stream().allMatch(UntrustedInputExample::destinationAllowed);
    }

    static boolean bindingStable(Set<AddressClass> validated, Set<AddressClass> atConnect) {
        return !validated.isEmpty()
                && validated.equals(atConnect)
                && atConnect.stream().allMatch(AddressClass.GLOBAL_UNICAST::equals);
    }

    static Destination destination(String uri, AddressClass... classes) {
        return new Destination(URI.create(uri), Set.of(classes));
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
