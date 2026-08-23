package academy.servlet;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicInteger;

public final class ServletHarness {
    private ServletHarness() {
    }

    public static HttpServletRequest request(String method, String uri, String requestId,
            Map<String, String> parameters) {
        Map<String, Object> attributes = new LinkedHashMap<>();
        attributes.put("requestId", requestId);
        InvocationHandler handler = (proxy, invoked, arguments) -> switch (invoked.getName()) {
            case "getMethod" -> method;
            case "getRequestURI" -> uri;
            case "getParameter" -> parameters.get((String) arguments[0]);
            case "getParameterMap" -> parameters.entrySet().stream().collect(
                    java.util.stream.Collectors.toUnmodifiableMap(
                            Map.Entry::getKey, entry -> new String[] {entry.getValue()}));
            case "getAttribute" -> attributes.get((String) arguments[0]);
            case "setAttribute" -> {
                attributes.put((String) arguments[0], arguments[1]);
                yield null;
            }
            case "removeAttribute" -> {
                attributes.remove((String) arguments[0]);
                yield null;
            }
            case "getCharacterEncoding" -> StandardCharsets.UTF_8.name();
            case "getDispatcherType" -> jakarta.servlet.DispatcherType.REQUEST;
            case "isAsyncSupported", "isAsyncStarted" -> false;
            case "toString" -> "Request[" + requestId + "]";
            case "hashCode" -> System.identityHashCode(proxy);
            case "equals" -> proxy == arguments[0];
            default -> throw new UnsupportedOperationException("request method not modelled: " + invoked.getName());
        };
        return (HttpServletRequest) Proxy.newProxyInstance(
                ServletHarness.class.getClassLoader(), new Class<?>[] {HttpServletRequest.class}, handler);
    }

    public static ResponseCapture response() {
        ResponseState state = new ResponseState();
        InvocationHandler handler = (proxy, invoked, arguments) -> handleResponse(proxy, invoked, arguments, state);
        HttpServletResponse response = (HttpServletResponse) Proxy.newProxyInstance(
                ServletHarness.class.getClassLoader(), new Class<?>[] {HttpServletResponse.class}, handler);
        return new ResponseCapture(response, state);
    }

    private static Object handleResponse(Object proxy, Method invoked, Object[] arguments, ResponseState state)
            throws IOException {
        return switch (invoked.getName()) {
            case "setStatus" -> {
                if (state.committed) {
                    state.lateStatusAttempts.incrementAndGet();
                } else {
                    state.status = (int) arguments[0];
                }
                yield null;
            }
            case "getStatus" -> state.status;
            case "setHeader" -> {
                if (!state.committed) {
                    state.headers.put((String) arguments[0], (String) arguments[1]);
                }
                yield null;
            }
            case "addHeader" -> {
                if (!state.committed) {
                    state.headers.merge((String) arguments[0], (String) arguments[1],
                            (left, right) -> left + "," + right);
                }
                yield null;
            }
            case "getHeader" -> state.headers.get((String) arguments[0]);
            case "containsHeader" -> state.headers.containsKey((String) arguments[0]);
            case "setContentType" -> {
                if (!state.committed) {
                    state.contentType = (String) arguments[0];
                }
                yield null;
            }
            case "getContentType" -> state.contentType;
            case "setCharacterEncoding" -> {
                if (!state.committed) {
                    state.characterEncoding = (String) arguments[0];
                }
                yield null;
            }
            case "getCharacterEncoding" -> state.characterEncoding;
            case "getWriter" -> state.writer;
            case "flushBuffer" -> {
                state.writer.flush();
                state.committed = true;
                yield null;
            }
            case "isCommitted" -> state.committed;
            case "resetBuffer" -> {
                if (state.committed) {
                    throw new IllegalStateException("response already committed");
                }
                state.body.getBuffer().setLength(0);
                yield null;
            }
            case "reset" -> {
                if (state.committed) {
                    throw new IllegalStateException("response already committed");
                }
                state.status = 200;
                state.headers.clear();
                state.body.getBuffer().setLength(0);
                yield null;
            }
            case "toString" -> "Response[status=" + state.status + "]";
            case "hashCode" -> System.identityHashCode(proxy);
            case "equals" -> proxy == arguments[0];
            default -> throw new UnsupportedOperationException("response method not modelled: " + invoked.getName());
        };
    }

    public static void invoke(List<Filter> filters, HttpServlet servlet,
            HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {
        FilterChain chain = (req, res) -> servlet.service(req, res);
        for (int index = filters.size() - 1; index >= 0; index--) {
            Filter current = filters.get(index);
            FilterChain next = chain;
            chain = (req, res) -> current.doFilter(req, res, next);
        }
        chain.doFilter(request, response);
    }

    public static final class RequiredEquipmentFilter implements Filter {
        @Override
        public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
                throws IOException, ServletException {
            String equipmentId = request.getParameter("equipmentId");
            if (equipmentId == null || equipmentId.isBlank()) {
                HttpServletResponse http = (HttpServletResponse) response;
                http.setStatus(400);
                http.setContentType("text/plain;charset=UTF-8");
                http.getWriter().print("missing equipmentId");
                http.flushBuffer();
                return;
            }
            chain.doFilter(request, response);
        }
    }

    public static final class TraceFilter implements Filter {
        private final List<String> events;

        public TraceFilter(List<String> events) {
            this.events = Objects.requireNonNull(events);
        }

        @Override
        public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
                throws IOException, ServletException {
            String requestId = String.valueOf(request.getAttribute("requestId"));
            events.add("before:" + requestId);
            try {
                chain.doFilter(request, response);
            } finally {
                events.add("after:" + requestId);
            }
        }
    }

    public static final class WorkOrderServlet extends HttpServlet {
        private final List<String> events;
        private final AtomicInteger calls = new AtomicInteger();

        public WorkOrderServlet(List<String> events) {
            this.events = Objects.requireNonNull(events);
        }

        @Override
        protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
            String equipmentId = request.getParameter("equipmentId");
            String requestId = String.valueOf(request.getAttribute("requestId"));
            calls.incrementAndGet();
            events.add("servlet:" + requestId);
            response.setStatus(200);
            response.setHeader("X-Request-Id", requestId);
            response.setContentType("text/plain;charset=UTF-8");
            response.getWriter().print("equipment=" + equipmentId);
            response.flushBuffer();
        }

        public int calls() {
            return calls.get();
        }
    }

    public static final class StoppingFilter implements Filter {
        @Override
        public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain) {
            // Deliberate fault: neither continue the chain nor construct a rejection response.
        }
    }

    public static final class LateStatusServlet extends HttpServlet {
        @Override
        protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException {
            response.setStatus(200);
            response.getWriter().print("partial");
            response.flushBuffer();
            response.setStatus(500);
        }
    }

    public static final class RetainingHandler {
        private volatile HttpServletRequest retained;

        public void retain(HttpServletRequest request) {
            retained = request;
        }

        public String currentEquipment() {
            return retained.getParameter("equipmentId");
        }
    }

    public record ResponseCapture(HttpServletResponse response, ResponseState state) {
    }

    public static final class ResponseState {
        private int status = 200;
        private String contentType;
        private String characterEncoding = StandardCharsets.UTF_8.name();
        private boolean committed;
        private final StringWriter body = new StringWriter();
        private final PrintWriter writer = new PrintWriter(body);
        private final Map<String, String> headers = new LinkedHashMap<>();
        private final AtomicInteger lateStatusAttempts = new AtomicInteger();

        public int status() {
            return status;
        }

        public String contentType() {
            return contentType;
        }

        public boolean committed() {
            return committed;
        }

        public String body() {
            writer.flush();
            return body.toString();
        }

        public String header(String name) {
            return headers.get(name);
        }

        public int lateStatusAttempts() {
            return lateStatusAttempts.get();
        }
    }
}
