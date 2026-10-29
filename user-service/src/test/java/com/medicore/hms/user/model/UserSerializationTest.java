package com.medicore.hms.user.model;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

public class UserSerializationTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    @DisplayName("TITANOPS-108: User password hash MUST NOT be leaked in JSON serialization")
    public void testPasswordExcludedFromSerialization() throws Exception {
        User user = new User();
        user.setId(101L);
        user.setUsername("dr_smith");
        user.setPassword("$2a$10$7EqJtq98hPqEX7fNZaFWoOhi5F786rMA52Jk1rO1q.HkZk3Y1rKfe");
        user.setRole("STAFF");

        String json = objectMapper.writeValueAsString(user);

        // Verify password key and value are completely omitted
        assertThat(json).doesNotContain("password");
        assertThat(json).doesNotContain("$2a$10$7EqJtq98hPqEX7fNZaFWoOhi5F786rMA52Jk1rO1q.HkZk3Y1rKfe");
        assertThat(json).contains("\"username\":\"dr_smith\"");
        assertThat(json).contains("\"role\":\"STAFF\"");
    }

    @Test
    @DisplayName("TITANOPS-108: Inbound password MUST still deserialize for registration/login payloads")
    public void testPasswordDeserializationPermitted() throws Exception {
        String inputJson = "{\"username\":\"new_nurse\",\"password\":\"P@ssw0rdSecure!\",\"role\":\"STAFF\"}";

        User deserialized = objectMapper.readValue(inputJson, User.class);

        assertThat(deserialized.getUsername()).isEqualTo("new_nurse");
        assertThat(deserialized.getPassword()).isEqualTo("P@ssw0rdSecure!");
        assertThat(deserialized.getRole()).isEqualTo("STAFF");
    }
}
