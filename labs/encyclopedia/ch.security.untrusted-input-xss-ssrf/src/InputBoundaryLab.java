import java.net.URI;
import java.util.List;
import java.util.Set;

/** Offline fault injection for browser output and server egress decisions. */
public final class InputBoundaryLab {
    enum FaultMode {
        NONE, CSRF_DISABLED, RAW_HTML, EVENT_ATTRIBUTE,
        LOOPBACK_ALLOWED, REDIRECT_UNCHECKED, DNS_REBINDING
    }

    enum AddressClass { GLOBAL_UNICAST, LOOPBACK, PRIVATE, LINK_LOCAL }

    record Destination(URI uri, Set<AddressClass> addresses) { }

    static final class Boundary {
        private final FaultMode mode;

        Boundary(FaultMode mode) {
            this.mode = mode;
        }

        boolean stateChangeAllowed(String origin, String token) {
            if (mode == FaultMode.CSRF_DISABLED) {
                return true;
            }
            return "https://app.factorycare.example.test".equals(origin)
                    && "SYNTHETIC-CSRF".equals(token);
        }

        String renderText(String value) {
            if (mode == FaultMode.RAW_HTML) {
                return value;
            }
            return value.replace("&", "&amp;")
                    .replace("<", "&lt;")
                    .replace(">", "&gt;")
                    .replace("\"", "&quot;")
                    .replace("'", "&#x27;");
        }

        boolean attributeAllowed(String name) {
            if (mode == FaultMode.EVENT_ATTRIBUTE) {
                return true;
            }
            return Set.of("title", "aria-label", "data-label").contains(name);
        }

        boolean destinationAllowed(Destination destination) {
            URI uri = destination.uri();
            int port = uri.getPort() == -1 ? 443 : uri.getPort();
            boolean structure = "https".equals(uri.getScheme())
                    && uri.getUserInfo() == null
                    && "manuals.factorycare.example.test".equals(uri.getHost())
                    && port == 443;
            if (mode == FaultMode.LOOPBACK_ALLOWED && destination.addresses().contains(AddressClass.LOOPBACK)) {
                return true;
            }
            return structure
                    && !destination.addresses().isEmpty()
                    && destination.addresses().stream().allMatch(AddressClass.GLOBAL_UNICAST::equals);
        }

        boolean redirectAllowed(List<Destination> hops) {
            if (hops.isEmpty()) {
                return false;
            }
            if (mode == FaultMode.REDIRECT_UNCHECKED) {
                return destinationAllowed(hops.getFirst());
            }
            return hops.stream().allMatch(this::destinationAllowed);
        }

        boolean bindingStable(Set<AddressClass> validated, Set<AddressClass> atConnect) {
            if (mode == FaultMode.DNS_REBINDING) {
                return true;
            }
            return !validated.isEmpty()
                    && validated.equals(atConnect)
                    && atConnect.stream().allMatch(AddressClass.GLOBAL_UNICAST::equals);
        }
    }

    private InputBoundaryLab() { }

    public static void main(String[] args) {
        FaultMode mode = args.length == 0 ? FaultMode.NONE : FaultMode.valueOf(args[0]);
        Boundary boundary = new Boundary(mode);

        require(!boundary.stateChangeAllowed("https://attacker.example.test", null),
                "CROSS_SITE_WRITE_ACCEPTED");
        String rendered = boundary.renderText("<img src=x onerror=syntheticAction()>");
        require(!rendered.contains("<img"), "ACTIVE_MARKUP_REACHED_SINK");
        require(!boundary.attributeAllowed("onerror"), "DANGEROUS_ATTRIBUTE_ACCEPTED");

        Destination allowed = destination(
                "https://manuals.factorycare.example.test/guides/1", AddressClass.GLOBAL_UNICAST);
        Destination nonHttps = destination(
                "http://manuals.factorycare.example.test/guides/1", AddressClass.GLOBAL_UNICAST);
        Destination loopback = destination("https://127.0.0.1/admin", AddressClass.LOOPBACK);
        require(boundary.destinationAllowed(allowed), "ALLOWED_DESTINATION_REJECTED");
        require(!boundary.destinationAllowed(nonHttps), "NON_ALLOWED_SCHEME_ACCEPTED");
        require(!boundary.destinationAllowed(loopback), "LOOPBACK_DESTINATION_ACCEPTED");

        Destination privateRedirect = destination(
                "https://metadata.factorycare.example.test/latest", AddressClass.LINK_LOCAL);
        require(!boundary.redirectAllowed(List.of(allowed, privateRedirect)),
                "REDIRECT_BOUNDARY_BYPASSED");
        require(!boundary.bindingStable(
                Set.of(AddressClass.GLOBAL_UNICAST), Set.of(AddressClass.LOOPBACK)),
                "DNS_REBINDING_ACCEPTED");

        System.out.println("cross_site_write_rejected=true");
        System.out.println("html_text_safe=true");
        System.out.println("event_attribute_rejected=true");
        System.out.println("scheme_allowlist=true");
        System.out.println("private_address_rejected=true");
        System.out.println("redirect_revalidated=true");
        System.out.println("dns_rebinding_rejected=true");
        System.out.println("verification_report=PASS assertions=9");
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
