package com.medicore.hms.medication.controller;

import com.medicore.hms.medication.model.Medication;
import com.medicore.hms.medication.service.MedicationService;
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
@RequestMapping("/api/medications")
public class MedicationController {

    private static final Logger log = LoggerFactory.getLogger(MedicationController.class);

    @Autowired
    private MedicationService medicationService;

    @PostMapping
    @WithSpan("MedicationController.createMedication")
    public ResponseEntity<Medication> createMedication(@RequestBody Medication medication) {
        log.info("POST /api/medications name={}", medication.getMedicationName());
        try {
            Medication saved = medicationService.createMedication(medication);
            log.info("POST /api/medications -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("POST /api/medications failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}")
    @WithSpan("MedicationController.getMedicationById")
    public ResponseEntity<Medication> getMedicationById(@PathVariable @SpanAttribute("medication.id") Long id) {
        log.info("GET /api/medications/{}", id);
        try {
            Optional<Medication> med = medicationService.getMedicationById(id);
            if (med.isPresent()) { log.info("GET /api/medications/{} -> 200", id); return ResponseEntity.ok(med.get()); }
            log.warn("GET /api/medications/{} -> 404", id); return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("GET /api/medications/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping
    @WithSpan("MedicationController.getAllMedications")
    public ResponseEntity<List<Medication>> getAllMedications() {
        log.info("GET /api/medications");
        try {
            List<Medication> list = medicationService.getAllMedications();
            log.info("GET /api/medications -> 200 count={}", list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/medications failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/search")
    @WithSpan("MedicationController.searchMedications")
    public ResponseEntity<List<Medication>> searchMedications(@RequestParam @SpanAttribute("search.query") String query) {
        log.info("GET /api/medications/search query='{}'", query);
        try {
            List<Medication> list = medicationService.searchMedications(query);
            log.info("GET /api/medications/search -> 200 count={}", list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/medications/search failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{id}")
    @WithSpan("MedicationController.updateMedication")
    public ResponseEntity<Medication> updateMedication(@PathVariable @SpanAttribute("medication.id") Long id, @RequestBody Medication medication) {
        log.info("PUT /api/medications/{}", id);
        try {
            medication.setId(id);
            Medication updated = medicationService.updateMedication(medication);
            log.info("PUT /api/medications/{} -> 200", id);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            log.error("PUT /api/medications/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/{id}")
    @WithSpan("MedicationController.deleteMedication")
    public ResponseEntity<Void> deleteMedication(@PathVariable @SpanAttribute("medication.id") Long id) {
        log.info("DELETE /api/medications/{}", id);
        try {
            medicationService.deleteMedication(id);
            log.info("DELETE /api/medications/{} -> 204", id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            log.error("DELETE /api/medications/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
