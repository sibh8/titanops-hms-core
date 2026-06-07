package com.medicore.hms.provider.controller;

import com.medicore.hms.provider.model.Provider;
import com.medicore.hms.provider.service.ProviderService;
import io.opentelemetry.instrumentation.annotations.SpanAttribute;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/providers")
public class ProviderController {

    private static final Logger log = LoggerFactory.getLogger(ProviderController.class);

    @Autowired
    private ProviderService providerService;

    @PostMapping
    @WithSpan("ProviderController.createProvider")
    public ResponseEntity<Provider> createProvider(@RequestBody Provider provider) {
        log.info("POST /api/providers name={} {} speciality={}", provider.getFirstName(), provider.getLastName(), provider.getSpeciality());
        try {
            Provider saved = providerService.createProvider(provider);
            log.info("POST /api/providers -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("POST /api/providers failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}")
    @WithSpan("ProviderController.getProviderById")
    public ResponseEntity<Provider> getProviderById(@PathVariable @SpanAttribute("provider.id") Long id) {
        log.info("GET /api/providers/{}", id);
        try {
            Optional<Provider> provider = providerService.getProviderById(id);
            if (provider.isPresent()) { log.info("GET /api/providers/{} -> 200", id); return ResponseEntity.ok(provider.get()); }
            log.warn("GET /api/providers/{} -> 404", id); return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("GET /api/providers/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping
    @WithSpan("ProviderController.getAllProviders")
    public ResponseEntity<List<Provider>> getAllProviders() {
        log.info("GET /api/providers");
        try {
            List<Provider> list = providerService.getAllProviders();
            log.info("GET /api/providers -> 200 count={}", list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/providers failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/active")
    @WithSpan("ProviderController.getActiveProviders")
    public ResponseEntity<List<Provider>> getActiveProviders() {
        log.info("GET /api/providers/active");
        try {
            List<Provider> list = providerService.getActiveProviders();
            log.info("GET /api/providers/active -> 200 count={}", list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/providers/active failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{id}")
    @WithSpan("ProviderController.updateProvider")
    public ResponseEntity<Provider> updateProvider(@PathVariable @SpanAttribute("provider.id") Long id, @RequestBody Provider provider) {
        log.info("PUT /api/providers/{}", id);
        try {
            provider.setId(id);
            Provider updated = providerService.updateProvider(provider);
            log.info("PUT /api/providers/{} -> 200", id);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            log.error("PUT /api/providers/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/{id}")
    @WithSpan("ProviderController.deleteProvider")
    public ResponseEntity<Void> deleteProvider(@PathVariable @SpanAttribute("provider.id") Long id) {
        log.info("DELETE /api/providers/{}", id);
        try {
            providerService.deleteProvider(id);
            log.info("DELETE /api/providers/{} -> 204", id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            log.error("DELETE /api/providers/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
