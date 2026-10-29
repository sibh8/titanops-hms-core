package com.medicore.hms.user.validation;

import com.medicore.hms.user.dto.LoginRequest;
import com.medicore.hms.user.model.User;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import javax.validation.ConstraintViolation;
import javax.validation.Validation;
import javax.validation.Validator;
import javax.validation.ValidatorFactory;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

public class PayloadValidationTest {

    private static Validator validator;

    @BeforeAll
    public static void setUp() {
        ValidatorFactory factory = Validation.buildDefaultValidatorFactory();
        validator = factory.getValidator();
    }

    @Test
    @DisplayName("TITANOPS-111: Valid user payload passes Bean Validation with 0 violations")
    public void testValidUserPayload() {
        User user = new User();
        user.setUsername("valid_doctor");
        user.setPassword("SecurePass123!");
        user.setRole("STAFF");

        Set<ConstraintViolation<User>> violations = validator.validate(user);
        assertThat(violations).isEmpty();
    }

    @Test
    @DisplayName("TITANOPS-111: Blank username triggers @NotBlank constraint violation")
    public void testBlankUsernameFails() {
        User user = new User();
        user.setUsername("");
        user.setPassword("ValidPassword123!");
        user.setRole("STAFF");

        Set<ConstraintViolation<User>> violations = validator.validate(user);
        assertThat(violations).isNotEmpty();
        assertThat(violations).anyMatch(v -> v.getPropertyPath().toString().equals("username"));
    }

    @Test
    @DisplayName("TITANOPS-111: Short password (<6 chars) triggers @Size constraint violation")
    public void testShortPasswordFails() {
        User user = new User();
        user.setUsername("good_username");
        user.setPassword("123"); // Too short
        user.setRole("STAFF");

        Set<ConstraintViolation<User>> violations = validator.validate(user);
        assertThat(violations).isNotEmpty();
        assertThat(violations).anyMatch(v -> v.getPropertyPath().toString().equals("password"));
    }

    @Test
    @DisplayName("TITANOPS-111: Invalid role string triggers @Pattern constraint violation")
    public void testInvalidRoleFails() {
        User user = new User();
        user.setUsername("good_username");
        user.setPassword("SecurePassword123!");
        user.setRole("SUPERUSER_HACKER"); // Invalid

        Set<ConstraintViolation<User>> violations = validator.validate(user);
        assertThat(violations).isNotEmpty();
        assertThat(violations).anyMatch(v -> v.getPropertyPath().toString().equals("role"));
    }

    @Test
    @DisplayName("TITANOPS-111: LoginRequest validates non-blank username and password")
    public void testLoginRequestValidation() {
        LoginRequest valid = new LoginRequest("dr_jones", "SecretPass123!");
        assertThat(validator.validate(valid)).isEmpty();

        LoginRequest blank = new LoginRequest("", "");
        assertThat(validator.validate(blank)).hasSize(3); // blank user, short user, blank pass
    }
}
