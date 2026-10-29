package com.medicore.hms.user.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import javax.annotation.PostConstruct;
import java.util.Arrays;
import java.util.List;

@Configuration
public class CorsConfig implements WebMvcConfigurer {

    private static final Logger log = LoggerFactory.getLogger(CorsConfig.class);

    @Value("${cors.allowed-origins:http://localhost:3000,http://localhost:80,http://localhost:5173,https://medicore.hms,https://app.titanops.internal}")
    private String[] allowedOrigins;

    @PostConstruct
    public void validateOrigins() {
        log.info("Initialized explicit CORS policy. Configured allowed origins: {}", Arrays.toString(allowedOrigins));
        for (String origin : allowedOrigins) {
            if ("*".equals(origin.trim())) {
                log.error("SECURITY WARNING: Wildcard '*' detected in CORS configuration! Wildcards are prohibited in production.");
            }
        }
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOrigins(allowedOrigins)
                .allowedMethods("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS")
                .allowedHeaders("Authorization", "Content-Type", "Accept", "X-Requested-With", "Origin")
                .exposedHeaders("Authorization")
                .allowCredentials(true)
                .maxAge(3600);
    }

    @Bean
    @Order(Ordered.HIGHEST_PRECEDENCE)
    public CorsFilter corsFilter() {
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowCredentials(true);
        config.setAllowedOrigins(List.of(allowedOrigins));
        config.setAllowedHeaders(Arrays.asList("Authorization", "Content-Type", "Accept", "X-Requested-With", "Origin"));
        config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"));
        config.setExposedHeaders(List.of("Authorization"));
        config.setMaxAge(3600L);
        source.registerCorsConfiguration("/**", config);
        return new CorsFilter(source);
    }

    public String[] getAllowedOrigins() {
        return allowedOrigins;
    }

    public void setAllowedOrigins(String[] allowedOrigins) {
        this.allowedOrigins = allowedOrigins;
    }
}
