package academy.servlet;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Rejects requests without an equipment identifier before they reach the target servlet.
 */
public final class EquipmentGuardFilter implements Filter {
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        String equipmentId = request.getParameter("equipmentId");
        if (equipmentId == null || equipmentId.isBlank()) {
            HttpServletResponse http = (HttpServletResponse) response;
            http.setStatus(400);
            http.getWriter().print("missing equipmentId");
            http.flushBuffer();
            return;
        }

        // TODO: a valid request must continue to the next filter or servlet.
    }
}
