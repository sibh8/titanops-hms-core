package com.medicore.hms.user.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

public class LoginAttemptServiceTest {

    private LoginAttemptService attemptService;

    @BeforeEach
    public void setUp() {
        attemptService = new LoginAttemptService();
        attemptService.setMaxAttempts(3); // 3 attempts for test speed
        attemptService.setLockoutDurationSeconds(60); // 1 minute lockout
    }

    @Test
    @DisplayName("TITANOPS-109: Repeated failed logins trigger account lockout (isBlocked = true)")
    public void testAccountLockoutAfterMaxAttempts() {
        String username = "victim_doctor";

        assertThat(attemptService.isBlocked(username)).isFalse();

        // 1st failure
        attemptService.loginFailed(username);
        assertThat(attemptService.isBlocked(username)).isFalse();
        assertThat(attemptService.getAttempts(username)).isEqualTo(1);

        // 2nd failure
        attemptService.loginFailed(username);
        assertThat(attemptService.isBlocked(username)).isFalse();
        assertThat(attemptService.getAttempts(username)).isEqualTo(2);

        // 3rd failure -> Lockout triggered!
        attemptService.loginFailed(username);
        assertThat(attemptService.isBlocked(username)).isTrue();
        assertThat(attemptService.getRemainingLockoutSeconds(username)).isGreaterThan(0);
    }

    @Test
    @DisplayName("TITANOPS-109: Successful login resets failed attempts")
    public void testSuccessfulLoginResetsAttempts() {
        String username = "nurse_joy";

        attemptService.loginFailed(username);
        attemptService.loginFailed(username);
        assertThat(attemptService.getAttempts(username)).isEqualTo(2);

        // Succeeded
        attemptService.loginSucceeded(username);
        assertThat(attemptService.getAttempts(username)).isEqualTo(0);
        assertThat(attemptService.isBlocked(username)).isFalse();
    }

    @Test
    @DisplayName("TITANOPS-109: Admin unlockAccount immediately clears lockout")
    public void testAdminUnlockAccount() {
        String username = "locked_user";

        attemptService.loginFailed(username);
        attemptService.loginFailed(username);
        attemptService.loginFailed(username);
        assertThat(attemptService.isBlocked(username)).isTrue();

        // Admin unlocks
        attemptService.unlockAccount(username);
        assertThat(attemptService.isBlocked(username)).isFalse();
        assertThat(attemptService.getAttempts(username)).isEqualTo(0);
    }

    @Test
    @DisplayName("TITANOPS-109: Time-based automatic unlock recovers user access after expiration")
    public void testTimeBasedUnlockRecovery() {
        String username = "temporary_lock";
        attemptService.setLockoutDurationSeconds(-1); // Expired immediately

        attemptService.loginFailed(username);
        attemptService.loginFailed(username);
        attemptService.loginFailed(username);

        // Accessing isBlocked when expired will auto-unlock
        assertThat(attemptService.isBlocked(username)).isFalse();
    }
}
