package com.medicore.hms.user.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

public class JwtUtilTest {

    private JwtUtil jwtUtil;

    @BeforeEach
    public void setUp() {
        jwtUtil = new JwtUtil();
        jwtUtil.setSecretKey("TestSecretKeyForMediCoreHMSJwtValidation1234567890!");
        jwtUtil.setExpirationSeconds(3600); // 1 hour
    }

    @Test
    @DisplayName("TITANOPS-107: Generates signed standard RFC 7519 JWT with valid claims")
    public void testTokenGenerationAndValidation() {
        String token = jwtUtil.generateToken(42L, "nurse_joy", "STAFF");

        assertThat(token).isNotNull();
        String[] parts = token.split("\\.");
        assertThat(parts).hasSize(3);

        assertThat(jwtUtil.validateToken(token)).isTrue();
        assertThat(jwtUtil.getUsername(token)).isEqualTo("nurse_joy");
        assertThat(jwtUtil.getRole(token)).isEqualTo("STAFF");
        assertThat(jwtUtil.getUserId(token)).isEqualTo(42L);
    }

    @Test
    @DisplayName("TITANOPS-107: Tampered JWT token signature MUST be rejected (401)")
    public void testTamperedTokenFailsValidation() {
        String token = jwtUtil.generateToken(1L, "admin_user", "ADMIN");
        String[] parts = token.split("\\.");
        
        // Tamper with payload
        String tamperedToken = parts[0] + ".eyJuYW1lIjoidGFtcGVyZWQifQ." + parts[2];
        assertThat(jwtUtil.validateToken(tamperedToken)).isFalse();
    }

    @Test
    @DisplayName("TITANOPS-107: Expired JWT token MUST be rejected (401)")
    public void testExpiredTokenFailsValidation() {
        jwtUtil.setExpirationSeconds(-10); // Expired 10 seconds ago
        String expiredToken = jwtUtil.generateToken(2L, "expired_user", "STAFF");

        assertThat(jwtUtil.validateToken(expiredToken)).isFalse();
    }
}
