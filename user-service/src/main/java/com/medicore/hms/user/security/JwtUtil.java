package com.medicore.hms.user.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

@Component
public class JwtUtil {

    private static final String HMAC_SHA256 = "HmacSHA256";
    private static final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${jwt.secret:MediCoreHMS_SecretKey_For_JWT_Signing_2026_Secure!}")
    private String secretKey;

    @Value("${jwt.expiration:86400}")
    private long expirationSeconds;

    public String generateToken(Long userId, String username, String role) {
        try {
            long nowSeconds = System.currentTimeMillis() / 1000;
            long expSeconds = nowSeconds + expirationSeconds;

            Map<String, Object> header = new HashMap<>();
            header.put("alg", "HS256");
            header.put("typ", "JWT");

            Map<String, Object> payload = new HashMap<>();
            payload.put("sub", username);
            payload.put("userId", userId);
            payload.put("role", role != null ? role.toUpperCase() : "STAFF");
            payload.put("iat", nowSeconds);
            payload.put("exp", expSeconds);

            String encodedHeader = base64UrlEncode(objectMapper.writeValueAsBytes(header));
            String encodedPayload = base64UrlEncode(objectMapper.writeValueAsBytes(payload));

            String dataToSign = encodedHeader + "." + encodedPayload;
            String signature = sign(dataToSign, secretKey);

            return dataToSign + "." + signature;
        } catch (Exception e) {
            throw new RuntimeException("Failed to generate JWT token", e);
        }
    }

    public boolean validateToken(String token) {
        try {
            String[] parts = token.split("\\.");
            if (parts.length != 3) {
                return false;
            }

            String dataToSign = parts[0] + "." + parts[1];
            String expectedSignature = sign(dataToSign, secretKey);

            // Constant-time comparison to prevent timing attacks
            if (!MessageDigest.isEqual(parts[2].getBytes(StandardCharsets.UTF_8), expectedSignature.getBytes(StandardCharsets.UTF_8))) {
                return false;
            }

            // Check expiration
            byte[] payloadBytes = Base64.getUrlDecoder().decode(parts[1]);
            Map<?, ?> claims = objectMapper.readValue(payloadBytes, Map.class);
            Number exp = (Number) claims.get("exp");
            if (exp == null || exp.longValue() < (System.currentTimeMillis() / 1000)) {
                return false; // Expired
            }

            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public Map<String, Object> getClaims(String token) {
        try {
            String[] parts = token.split("\\.");
            byte[] payloadBytes = Base64.getUrlDecoder().decode(parts[1]);
            return objectMapper.readValue(payloadBytes, Map.class);
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid token payload", e);
        }
    }

    public String getUsername(String token) {
        return (String) getClaims(token).get("sub");
    }

    public String getRole(String token) {
        return (String) getClaims(token).get("role");
    }

    public Long getUserId(String token) {
        Number id = (Number) getClaims(token).get("userId");
        return id != null ? id.longValue() : null;
    }

    private String sign(String data, String key) throws Exception {
        Mac mac = Mac.getInstance(HMAC_SHA256);
        SecretKeySpec secretKeySpec = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), HMAC_SHA256);
        mac.init(secretKeySpec);
        byte[] signatureBytes = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
        return base64UrlEncode(signatureBytes);
    }

    private String base64UrlEncode(byte[] bytes) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    // Setter for testing
    public void setSecretKey(String secretKey) {
        this.secretKey = secretKey;
    }

    public void setExpirationSeconds(long expirationSeconds) {
        this.expirationSeconds = expirationSeconds;
    }
}
