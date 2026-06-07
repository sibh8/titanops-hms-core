package com.medicore.hms.prescription.controller;

import com.medicore.hms.prescription.model.Prescription;
import com.medicore.hms.prescription.model.PrescriptionItem;
import com.medicore.hms.prescription.service.PrescriptionService;
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
@RequestMapping("/api/prescriptions")
public class PrescriptionController {

    private static final Logger log = LoggerFactory.getLogger(PrescriptionController.class);

    @Autowired
    private PrescriptionService prescriptionService;

    @PostMapping
    @WithSpan("PrescriptionController.createPrescription")
    public ResponseEntity<Prescription> createPrescription(@RequestBody Prescription prescription) {
        log.info("POST /api/prescriptions patientId={} providerId={}", prescription.getPatientId(), prescription.getProviderId());
        try {
            Prescription saved = prescriptionService.createPrescription(prescription);
            log.info("POST /api/prescriptions -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("POST /api/prescriptions failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}")
    @WithSpan("PrescriptionController.getPrescriptionById")
    public ResponseEntity<Prescription> getPrescriptionById(@PathVariable @SpanAttribute("prescription.id") Long id) {
        log.info("GET /api/prescriptions/{}", id);
        try {
            Optional<Prescription> rx = prescriptionService.getPrescriptionById(id);
            if (rx.isPresent()) { log.info("GET /api/prescriptions/{} -> 200", id); return ResponseEntity.ok(rx.get()); }
            log.warn("GET /api/prescriptions/{} -> 404", id); return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("GET /api/prescriptions/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping
    @WithSpan("PrescriptionController.getAllPrescriptions")
    public ResponseEntity<List<Prescription>> getAllPrescriptions() {
        log.info("GET /api/prescriptions");
        try {
            List<Prescription> list = prescriptionService.getAllPrescriptions();
            log.info("GET /api/prescriptions -> 200 count={}", list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/prescriptions failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/patient/{patientId}")
    @WithSpan("PrescriptionController.getByPatientId")
    public ResponseEntity<List<Prescription>> getByPatientId(@PathVariable @SpanAttribute("patient.id") Long patientId) {
        log.info("GET /api/prescriptions/patient/{}", patientId);
        try {
            List<Prescription> list = prescriptionService.getPrescriptionsByPatientId(patientId);
            log.info("GET /api/prescriptions/patient/{} -> 200 count={}", patientId, list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/prescriptions/patient/{} failed: {}", patientId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{id}")
    @WithSpan("PrescriptionController.updatePrescription")
    public ResponseEntity<Prescription> updatePrescription(@PathVariable @SpanAttribute("prescription.id") Long id, @RequestBody Prescription prescription) {
        log.info("PUT /api/prescriptions/{}", id);
        try {
            prescription.setId(id);
            Prescription updated = prescriptionService.updatePrescription(prescription);
            log.info("PUT /api/prescriptions/{} -> 200", id);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            log.error("PUT /api/prescriptions/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/{id}")
    @WithSpan("PrescriptionController.deletePrescription")
    public ResponseEntity<Void> deletePrescription(@PathVariable @SpanAttribute("prescription.id") Long id) {
        log.info("DELETE /api/prescriptions/{}", id);
        try {
            prescriptionService.deletePrescription(id);
            log.info("DELETE /api/prescriptions/{} -> 204", id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            log.error("DELETE /api/prescriptions/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/{id}/items")
    @WithSpan("PrescriptionController.addItem")
    public ResponseEntity<PrescriptionItem> addItem(@PathVariable @SpanAttribute("prescription.id") Long id, @RequestBody PrescriptionItem item) {
        log.info("POST /api/prescriptions/{}/items medicationId={}", id, item.getMedicationId());
        try {
            item.setPrescriptionId(id);
            PrescriptionItem saved = prescriptionService.addPrescriptionItem(item);
            log.info("POST /api/prescriptions/{}/items -> 201 id={}", id, saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("POST /api/prescriptions/{}/items failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}/items")
    @WithSpan("PrescriptionController.getItems")
    public ResponseEntity<List<PrescriptionItem>> getItems(@PathVariable @SpanAttribute("prescription.id") Long id) {
        log.info("GET /api/prescriptions/{}/items", id);
        try {
            List<PrescriptionItem> list = prescriptionService.getItemsByPrescriptionId(id);
            log.info("GET /api/prescriptions/{}/items -> 200 count={}", id, list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/prescriptions/{}/items failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
