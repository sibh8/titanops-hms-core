package com.medicore.hms.encounter.controller;

import com.medicore.hms.encounter.model.Encounter;
import com.medicore.hms.encounter.service.EncounterService;
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
@RequestMapping("/api/encounters")
public class EncounterController {

    private static final Logger log = LoggerFactory.getLogger(EncounterController.class);

    @Autowired
    private EncounterService encounterService;

    @PostMapping
    @WithSpan("EncounterController.createEncounter")
    public ResponseEntity<Encounter> createEncounter(@RequestBody Encounter encounter) {
        log.info("POST /api/encounters patientId={} providerId={}", encounter.getPatientId(), encounter.getProviderId());
        try {
            Encounter saved = encounterService.createEncounter(encounter);
            log.info("POST /api/encounters -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("POST /api/encounters failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}")
    @WithSpan("EncounterController.getEncounterById")
    public ResponseEntity<Encounter> getEncounterById(@PathVariable @SpanAttribute("encounter.id") Long id) {
        log.info("GET /api/encounters/{}", id);
        try {
            Optional<Encounter> enc = encounterService.getEncounterById(id);
            if (enc.isPresent()) { log.info("GET /api/encounters/{} -> 200", id); return ResponseEntity.ok(enc.get()); }
            log.warn("GET /api/encounters/{} -> 404", id); return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("GET /api/encounters/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping
    @WithSpan("EncounterController.getAllEncounters")
    public ResponseEntity<List<Encounter>> getAllEncounters() {
        log.info("GET /api/encounters");
        try {
            List<Encounter> list = encounterService.getAllEncounters();
            log.info("GET /api/encounters -> 200 count={}", list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/encounters failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/patient/{patientId}")
    @WithSpan("EncounterController.getByPatientId")
    public ResponseEntity<List<Encounter>> getByPatientId(@PathVariable @SpanAttribute("patient.id") Long patientId) {
        log.info("GET /api/encounters/patient/{}", patientId);
        try {
            List<Encounter> list = encounterService.getEncountersByPatientId(patientId);
            log.info("GET /api/encounters/patient/{} -> 200 count={}", patientId, list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/encounters/patient/{} failed: {}", patientId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{id}")
    @WithSpan("EncounterController.updateEncounter")
    public ResponseEntity<Encounter> updateEncounter(@PathVariable @SpanAttribute("encounter.id") Long id, @RequestBody Encounter encounter) {
        log.info("PUT /api/encounters/{}", id);
        try {
            encounter.setId(id);
            Encounter updated = encounterService.updateEncounter(encounter);
            log.info("PUT /api/encounters/{} -> 200", id);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            log.error("PUT /api/encounters/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/{id}")
    @WithSpan("EncounterController.deleteEncounter")
    public ResponseEntity<Void> deleteEncounter(@PathVariable @SpanAttribute("encounter.id") Long id) {
        log.info("DELETE /api/encounters/{}", id);
        try {
            encounterService.deleteEncounter(id);
            log.info("DELETE /api/encounters/{} -> 204", id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            log.error("DELETE /api/encounters/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
