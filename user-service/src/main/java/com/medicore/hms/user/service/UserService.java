package com.medicore.hms.user.service;

import com.medicore.hms.user.model.User;
import com.medicore.hms.user.repository.UserRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.instrumentation.annotations.SpanAttribute;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.util.List;
import java.util.Optional;

@Service
public class UserService {

    private static final Logger log = LoggerFactory.getLogger(UserService.class);
    private static final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private MeterRegistry meterRegistry;

    private Counter loginSuccesses;
    private Counter loginFailures;
    private Counter userRegistrations;

    @PostConstruct
    public void initMetrics() {
        loginSuccesses = Counter.builder("medicore.user.login.success.total")
                .description("Total number of successful logins")
                .tag("service", "user-service")
                .register(meterRegistry);

        loginFailures = Counter.builder("medicore.user.login.failure.total")
                .description("Total number of failed login attempts")
                .tag("service", "user-service")
                .register(meterRegistry);

        userRegistrations = Counter.builder("medicore.user.registrations.total")
                .description("Total number of user registrations")
                .tag("service", "user-service")
                .register(meterRegistry);

        Gauge.builder("medicore.user.active.count", userRepository, repo -> {
                    try {
                        return repo.count();
                    } catch (Exception e) {
                        return 0;
                    }
                })
                .description("Total number of registered users")
                .tag("service", "user-service")
                .register(meterRegistry);
    }

    @WithSpan("UserService.createUser")
    public User createUser(User user) {
        Span span = Span.current();
        span.setAttribute("user.username", user.getUsername() != null ? user.getUsername() : "");
        span.setAttribute("user.role",     user.getRole()     != null ? user.getRole()     : "");
        log.info("Creating user username={} role={}", user.getUsername(), user.getRole());
        try {
            // Duplicate username check
            if (userRepository.findByUsername(user.getUsername()).isPresent()) {
                log.warn("Registration rejected — username already exists: {}", user.getUsername());
                throw new IllegalArgumentException("Username already taken: " + user.getUsername());
            }
            // Hash password before persisting
            if (user.getPassword() != null && !user.getPassword().isEmpty()) {
                user.setPassword(passwordEncoder.encode(user.getPassword()));
            }
            User saved = userRepository.save(user);
            span.setAttribute("user.id", saved.getId());
            userRegistrations.increment(); // Increment business metric
            log.info("User created successfully id={} username={}", saved.getId(), saved.getUsername());
            return saved;
        } catch (IllegalArgumentException e) {
            span.setStatus(StatusCode.ERROR, e.getMessage());
            throw e;
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to create user username={}: {}", user.getUsername(), e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("UserService.getUserById")
    public Optional<User> getUserById(@SpanAttribute("user.id") Long id) {
        log.debug("Fetching user id={}", id);
        try {
            Optional<User> result = userRepository.findById(id);
            Span.current().setAttribute("user.found", result.isPresent());
            log.info("User lookup id={} found={}", id, result.isPresent());
            return result;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching user id={}: {}", id, e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("UserService.getAllUsers")
    public List<User> getAllUsers() {
        log.debug("Fetching all users");
        try {
            List<User> users = userRepository.findAll();
            Span.current().setAttribute("users.count", users.size());
            log.info("Retrieved {} users", users.size());
            return users;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching all users: {}", e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("UserService.getUserByUsername")
    public Optional<User> getUserByUsername(@SpanAttribute("user.username") String username) {
        log.info("Fetching user by username={}", username);
        try {
            Optional<User> result = userRepository.findByUsername(username);
            Span.current().setAttribute("user.found", result.isPresent());
            log.info("User lookup username={} found={}", username, result.isPresent());
            return result;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching user username={}: {}", username, e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("UserService.updateUser")
    public User updateUser(User user) {
        Span.current().setAttribute("user.id", user.getId() != null ? user.getId() : -1L);
        log.info("Updating user id={}", user.getId());
        try {
            User updated = userRepository.save(user);
            log.info("User updated successfully id={}", updated.getId());
            return updated;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to update user id={}: {}", user.getId(), e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("UserService.deleteUser")
    public void deleteUser(@SpanAttribute("user.id") Long id) {
        log.info("Deleting user id={}", id);
        try {
            userRepository.deleteById(id);
            log.info("User deleted id={}", id);
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to delete user id={}: {}", id, e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("UserService.loginUser")
    public Optional<User> loginUser(@SpanAttribute("user.username") String username, String rawPassword) {
        log.info("Login attempt for username={}", username);
        try {
            Optional<User> user = userRepository.findByUsername(username);
            if (user.isPresent() && passwordEncoder.matches(rawPassword, user.get().getPassword())) {
                Span.current().setAttribute("login.success", true);
                loginSuccesses.increment(); // Track successful login
                log.info("Login successful for username={}", username);
                return user;
            }
            Span.current().setAttribute("login.success", false);
            loginFailures.increment(); // Track failed login
            log.warn("Login failed for username={} - invalid credentials", username);
            return Optional.empty();
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Login error for username={}: {}", username, e.getMessage(), e);
            throw e;
        }
    }

}
