package com.medicore.hms.user.security;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class LoginAttemptService {

    private static final Logger log = LoggerFactory.getLogger(LoginAttemptService.class);

    @Value("${security.login.max-attempts:5}")
    private int maxAttempts;

    @Value("${security.login.lockout-duration-seconds:900}") // 15 minutes default
    private long lockoutDurationSeconds;

    @Autowired(required = false)
    private MeterRegistry meterRegistry;

    private Counter lockoutCounter;

    private final Map<String, Integer> attemptsCache = new ConcurrentHashMap<>();
    private final Map<String, Long> lockoutExpiryCache = new ConcurrentHashMap<>();

    @PostConstruct
    public void initMetrics() {
        if (meterRegistry != null) {
            lockoutCounter = Counter.builder("medicore.user.account.lockouts.total")
                    .description("Total number of account lockouts triggered by brute-force protection")
                    .tag("service", "user-service")
                    .register(meterRegistry);
        }
    }

    public boolean isBlocked(String key) {
        if (key == null) return false;
        String normalizedKey = key.trim().toLowerCase();

        Long expiry = lockoutExpiryCache.get(normalizedKey);
        if (expiry == null) {
            return false;
        }

        long now = System.currentTimeMillis();
        if (now < expiry) {
            return true; // Still locked out
        }

        // Time-based automatic unlock
        log.info("Lockout expired for key={}. Account automatically unlocked.", normalizedKey);
        unlockAccount(normalizedKey);
        return false;
    }

    public long getRemainingLockoutSeconds(String key) {
        if (key == null) return 0;
        String normalizedKey = key.trim().toLowerCase();
        Long expiry = lockoutExpiryCache.get(normalizedKey);
        if (expiry == null) return 0;
        long remainingMs = expiry - System.currentTimeMillis();
        return remainingMs > 0 ? (remainingMs / 1000) : 0;
    }

    public void loginSucceeded(String key) {
        if (key == null) return;
        String normalizedKey = key.trim().toLowerCase();
        attemptsCache.remove(normalizedKey);
        lockoutExpiryCache.remove(normalizedKey);
    }

    public void loginFailed(String key) {
        if (key == null) return;
        String normalizedKey = key.trim().toLowerCase();

        int attempts = attemptsCache.getOrDefault(normalizedKey, 0) + 1;
        attemptsCache.put(normalizedKey, attempts);
        log.warn("Login failure #{} for key={}", attempts, normalizedKey);

        if (attempts >= maxAttempts) {
            long expiryTime = System.currentTimeMillis() + (lockoutDurationSeconds * 1000);
            lockoutExpiryCache.put(normalizedKey, expiryTime);
            log.error("Account LOCKED OUT for key={} due to {} consecutive failures. Locked until timestamp={}",
                    normalizedKey, attempts, expiryTime);

            if (lockoutCounter != null) {
                lockoutCounter.increment();
            }
        }
    }

    public void unlockAccount(String key) {
        if (key == null) return;
        String normalizedKey = key.trim().toLowerCase();
        attemptsCache.remove(normalizedKey);
        lockoutExpiryCache.remove(normalizedKey);
        log.info("Account lock purged and reset for key={}", normalizedKey);
    }

    public int getAttempts(String key) {
        if (key == null) return 0;
        return attemptsCache.getOrDefault(key.trim().toLowerCase(), 0);
    }

    public void setMaxAttempts(int maxAttempts) {
        this.maxAttempts = maxAttempts;
    }

    public void setLockoutDurationSeconds(long lockoutDurationSeconds) {
        this.lockoutDurationSeconds = lockoutDurationSeconds;
    }
}
