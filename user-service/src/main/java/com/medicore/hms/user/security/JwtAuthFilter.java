package com.medicore.hms.user.security;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

@Component
@Order(1)
public class JwtAuthFilter extends OncePerRequestFilter {

    @Autowired
    private JwtUtil jwtUtil;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {

        String path = request.getRequestURI();
        String method = request.getMethod();

        // 1. Allow public auth endpoints, actuator metrics/health, error dispatch, and CORS preflight
        if ("OPTIONS".equalsIgnoreCase(method) ||
                path.startsWith("/api/auth/") ||
                path.startsWith("/actuator") ||
                path.startsWith("/error")) {
            filterChain.doFilter(request, response);
            return;
        }

        // 2. Validate Authorization header
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType("application/json");
            response.getWriter().write("{\"error\":\"Unauthorized\",\"message\":\"Missing or invalid Authorization header\"}");
            return;
        }

        String token = authHeader.substring(7).trim();
        if (!jwtUtil.validateToken(token)) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType("application/json");
            response.getWriter().write("{\"error\":\"Unauthorized\",\"message\":\"Token is invalid or expired\"}");
            return;
        }

        String username = jwtUtil.getUsername(token);
        String role = jwtUtil.getRole(token);

        request.setAttribute("authenticatedUser", username);
        request.setAttribute("authenticatedRole", role);

        // 3. Enforce Role-Based Access Control (RBAC): DELETE requires ADMIN role
        if ("DELETE".equalsIgnoreCase(method) && !("ADMIN".equalsIgnoreCase(role))) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType("application/json");
            response.getWriter().write("{\"error\":\"Forbidden\",\"message\":\"Role ADMIN required for destructive delete operations\"}");
            return;
        }

        filterChain.doFilter(request, response);
    }
}
