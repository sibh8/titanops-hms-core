package com.medicore.hms.user.config;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import java.io.IOException;

import static org.assertj.core.api.Assertions.assertThat;

public class CorsConfigTest {

    private CorsConfig corsConfig;
    private CorsFilter corsFilter;

    @BeforeEach
    public void setUp() {
        corsConfig = new CorsConfig();
        corsConfig.setAllowedOrigins(new String[]{
                "http://localhost:3000",
                "http://localhost:5173",
                "https://medicore.hms"
        });
        corsFilter = corsConfig.corsFilter();
    }

    @Test
    @DisplayName("TITANOPS-110: Preflight (OPTIONS) request from allowed origin receives CORS response headers")
    public void testAllowedOriginPreflightSucceeds() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest("OPTIONS", "/api/users");
        request.addHeader("Origin", "http://localhost:3000");
        request.addHeader("Access-Control-Request-Method", "POST");
        request.addHeader("Access-Control-Request-Headers", "Authorization, Content-Type");

        MockHttpServletResponse response = new MockHttpServletResponse();
        corsFilter.doFilter(request, response, (req, res) -> {});

        assertThat(response.getHeader("Access-Control-Allow-Origin")).isEqualTo("http://localhost:3000");
        assertThat(response.getHeader("Access-Control-Allow-Credentials")).isEqualTo("true");
        assertThat(response.getHeader("Access-Control-Allow-Methods")).contains("GET", "POST", "PUT", "DELETE", "OPTIONS");
    }

    @Test
    @DisplayName("TITANOPS-110: Preflight request from disallowed origin DOES NOT receive Access-Control-Allow-Origin")
    public void testDisallowedOriginPreflightFails() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest("OPTIONS", "/api/users");
        request.addHeader("Origin", "http://attacker-controlled-origin.com");
        request.addHeader("Access-Control-Request-Method", "POST");

        MockHttpServletResponse response = new MockHttpServletResponse();
        corsFilter.doFilter(request, response, (req, res) -> {});

        assertThat(response.getHeader("Access-Control-Allow-Origin")).isNull();
    }

    @Test
    @DisplayName("TITANOPS-110: No wildcard permitted in production allowed origins")
    public void testNoWildcardConfigured() {
        for (String origin : corsConfig.getAllowedOrigins()) {
            assertThat(origin).isNotEqualTo("*");
        }
    }
}
