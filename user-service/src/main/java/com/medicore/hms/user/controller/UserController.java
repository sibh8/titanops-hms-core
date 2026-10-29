package com.medicore.hms.user.controller;

import com.medicore.hms.user.model.User;
import com.medicore.hms.user.service.UserService;
import io.opentelemetry.instrumentation.annotations.SpanAttribute;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import javax.validation.Valid;

import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private static final Logger log = LoggerFactory.getLogger(UserController.class);

    @Autowired
    private UserService userService;

    @PostMapping
    @WithSpan("UserController.createUser")
    public ResponseEntity<User> createUser(@Valid @RequestBody User user) {
        log.info("POST /api/users username={}", user.getUsername());
        try {
            User saved = userService.createUser(user);
            log.info("POST /api/users -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (IllegalArgumentException e) {
            log.warn("POST /api/users -> 409 {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT).build();
        } catch (Exception e) {
            log.error("POST /api/users failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}")
    @WithSpan("UserController.getUserById")
    public ResponseEntity<User> getUserById(@PathVariable @SpanAttribute("user.id") Long id) {
        log.info("GET /api/users/{}", id);
        try {
            Optional<User> user = userService.getUserById(id);
            if (user.isPresent()) { log.info("GET /api/users/{} -> 200", id); return ResponseEntity.ok(user.get()); }
            log.warn("GET /api/users/{} -> 404", id); return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("GET /api/users/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping
    @WithSpan("UserController.getAllUsers")
    public ResponseEntity<List<User>> getAllUsers() {
        log.info("GET /api/users");
        try {
            List<User> users = userService.getAllUsers();
            log.info("GET /api/users -> 200 count={}", users.size());
            return ResponseEntity.ok(users);
        } catch (Exception e) {
            log.error("GET /api/users failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/username/{username}")
    @WithSpan("UserController.getUserByUsername")
    public ResponseEntity<User> getUserByUsername(@PathVariable @SpanAttribute("user.username") String username) {
        log.info("GET /api/users/username/{}", username);
        try {
            Optional<User> user = userService.getUserByUsername(username);
            if (user.isPresent()) { log.info("GET /api/users/username/{} -> 200", username); return ResponseEntity.ok(user.get()); }
            log.warn("GET /api/users/username/{} -> 404", username); return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("GET /api/users/username/{} failed: {}", username, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{id}")
    @WithSpan("UserController.updateUser")
    public ResponseEntity<User> updateUser(@PathVariable @SpanAttribute("user.id") Long id, @Valid @RequestBody User user) {
        log.info("PUT /api/users/{}", id);
        try {
            user.setId(id);
            User updated = userService.updateUser(user);
            log.info("PUT /api/users/{} -> 200", id);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            log.error("PUT /api/users/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/{id}")
    @WithSpan("UserController.deleteUser")
    public ResponseEntity<Void> deleteUser(@PathVariable @SpanAttribute("user.id") Long id) {
        log.info("DELETE /api/users/{}", id);
        try {
            userService.deleteUser(id);
            log.info("DELETE /api/users/{} -> 204", id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            log.error("DELETE /api/users/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @Autowired
    private com.medicore.hms.user.security.LoginAttemptService loginAttemptService;

    @PostMapping("/{username}/unlock")
    @WithSpan("UserController.unlockUser")
    public ResponseEntity<?> unlockUser(@PathVariable String username, javax.servlet.http.HttpServletRequest request) {
        String role = (String) request.getAttribute("authenticatedRole");
        if (role == null || !role.equalsIgnoreCase("ADMIN")) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(java.util.Map.of("error", "Forbidden", "message", "Admin role required to unlock accounts"));
        }
        loginAttemptService.unlockAccount(username);
        log.info("Admin {} unlocked account for {}", request.getAttribute("authenticatedUser"), username);
        return ResponseEntity.ok(java.util.Map.of("message", "Account successfully unlocked", "username", username));
    }
}
