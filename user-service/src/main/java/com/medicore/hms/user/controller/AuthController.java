package com.medicore.hms.user.controller;

import com.medicore.hms.user.model.User;
import com.medicore.hms.user.security.JwtUtil;
import com.medicore.hms.user.service.UserService;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Dedicated auth endpoints:
 *   POST /api/auth/register  – register a new user (hashes password, checks duplicate)
 *   POST /api/auth/login     – validate credentials, return JWT token and user profile
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private static final Logger log = LoggerFactory.getLogger(AuthController.class);

    @Autowired
    private UserService userService;

    @Autowired
    private JwtUtil jwtUtil;

    // ─── Register ────────────────────────────────────────────────────────────

    @PostMapping("/register")
    @WithSpan("AuthController.register")
    public ResponseEntity<User> register(@RequestBody User user) {
        log.info("POST /api/auth/register username={}", user.getUsername());
        if (user.getUsername() == null || user.getUsername().isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        if (user.getPassword() == null || user.getPassword().length() < 6) {
            return ResponseEntity.badRequest().build();
        }
        try {
            // Default role if not provided
            if (user.getRole() == null || user.getRole().isBlank()) {
                user.setRole("STAFF");
            }
            User saved = userService.createUser(user);
            log.info("POST /api/auth/register -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (IllegalArgumentException e) {
            log.warn("POST /api/auth/register -> 409 {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT).build();
        } catch (Exception e) {
            log.error("POST /api/auth/register failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ─── Login ───────────────────────────────────────────────────────────────

    @PostMapping("/login")
    @WithSpan("AuthController.login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> credentials) {
        String username = credentials.get("username");
        String password = credentials.get("password");
        log.info("POST /api/auth/login username={}", username);
        if (username == null || password == null) {
            return ResponseEntity.badRequest().build();
        }
        try {
            Optional<User> user = userService.loginUser(username, password);
            if (user.isPresent()) {
                User u = user.get();
                String token = jwtUtil.generateToken(u.getId(), u.getUsername(), u.getRole());
                log.info("POST /api/auth/login -> 200 id={} tokenIssued=true", u.getId());

                Map<String, Object> response = new HashMap<>();
                response.put("token", token);
                response.put("type", "Bearer");
                response.put("expiresIn", 86400);
                response.put("user", u);
                // Top-level fields for maximum compatibility
                response.put("id", u.getId());
                response.put("username", u.getUsername());
                response.put("role", u.getRole());

                return ResponseEntity.ok(response);
            }
            log.warn("POST /api/auth/login -> 401 invalid credentials for username={}", username);
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        } catch (Exception e) {
            log.error("POST /api/auth/login failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
