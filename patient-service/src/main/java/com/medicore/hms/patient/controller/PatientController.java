package com.medicore.hms.patient.controller;

import com.medicore.hms.patient.model.Patient;
import com.medicore.hms.patient.service.PatientService;
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
@RequestMapping("/api/patients")
public class PatientController {

    private static final Logger log = LoggerFactory.getLogger(PatientController.class);

    @Autowired
    private PatientService patientService;

    @PostMapping
    @WithSpan("PatientController.createPatient")
    public ResponseEntity<Patient> createPatient(@RequestBody Patient patient) {
        log.info("POST /api/patients firstName={} lastName={}", patient.getFirstName(), patient.getLastName());
        try {
            Patient saved = patientService.createPatient(patient);
            log.info("POST /api/patients -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("POST /api/patients failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}")
    @WithSpan("PatientController.getPatientById")
    public ResponseEntity<Patient> getPatientById(@PathVariable @SpanAttribute("patient.id") Long id) {
        log.info("GET /api/patients/{}", id);
        try {
            Optional<Patient> patient = patientService.getPatientById(id);
            if (patient.isPresent()) {
                log.info("GET /api/patients/{} -> 200", id);
                return ResponseEntity.ok(patient.get());
            } else {
                log.warn("GET /api/patients/{} -> 404", id);
                return ResponseEntity.notFound().build();
            }
        } catch (Exception e) {
            log.error("GET /api/patients/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping
    @WithSpan("PatientController.getAllPatients")
    public ResponseEntity<List<Patient>> getAllPatients() {
        log.info("GET /api/patients");
        try {
            List<Patient> patients = patientService.getAllPatients();
            log.info("GET /api/patients -> 200 count={}", patients.size());
            return ResponseEntity.ok(patients);
        } catch (Exception e) {
            log.error("GET /api/patients failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/search")
    @WithSpan("PatientController.searchPatients")
    public ResponseEntity<List<Patient>> searchPatients(
            @RequestParam @SpanAttribute("search.query") String query) {
        log.info("GET /api/patients/search query='{}'", query);
        try {
            List<Patient> patients = patientService.searchPatients(query);
            log.info("GET /api/patients/search -> 200 count={}", patients.size());
            return ResponseEntity.ok(patients);
        } catch (Exception e) {
            log.error("GET /api/patients/search failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{id}")
    @WithSpan("PatientController.updatePatient")
    public ResponseEntity<Patient> updatePatient(
            @PathVariable @SpanAttribute("patient.id") Long id,
            @RequestBody Patient patient) {
        log.info("PUT /api/patients/{}", id);
        try {
            patient.setId(id);
            Patient updated = patientService.updatePatient(patient);
            log.info("PUT /api/patients/{} -> 200", id);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            log.error("PUT /api/patients/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/{id}")
    @WithSpan("PatientController.deletePatient")
    public ResponseEntity<Void> deletePatient(@PathVariable @SpanAttribute("patient.id") Long id) {
        log.info("DELETE /api/patients/{}", id);
        try {
            patientService.deletePatient(id);
            log.info("DELETE /api/patients/{} -> 204", id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            log.error("DELETE /api/patients/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
