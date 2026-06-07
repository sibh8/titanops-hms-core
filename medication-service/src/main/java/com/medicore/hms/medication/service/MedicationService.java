package com.medicore.hms.medication.service;

import com.medicore.hms.medication.model.Medication;
import com.medicore.hms.medication.repository.MedicationRepository;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.instrumentation.annotations.SpanAttribute;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class MedicationService {

    private static final Logger log = LoggerFactory.getLogger(MedicationService.class);

    @Autowired
    private MedicationRepository medicationRepository;

    @WithSpan("MedicationService.createMedication")
    public Medication createMedication(Medication medication) {
        Span span = Span.current();
        span.setAttribute("medication.name", medication.getMedicationName() != null ? medication.getMedicationName() : "");
        log.info("Creating medication name={}", medication.getMedicationName());
        try {
            Medication saved = medicationRepository.save(medication);
            span.setAttribute("medication.id", saved.getId());
            log.info("Medication created id={} name={}", saved.getId(), saved.getMedicationName());
            return saved;
        } catch (Exception e) {
            span.recordException(e); span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to create medication: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("MedicationService.getMedicationById")
    public Optional<Medication> getMedicationById(@SpanAttribute("medication.id") Long id) {
        log.debug("Fetching medication id={}", id);
        try {
            Optional<Medication> result = medicationRepository.findById(id);
            Span.current().setAttribute("medication.found", result.isPresent());
            log.info("Medication lookup id={} found={}", id, result.isPresent());
            return result;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching medication id={}: {}", id, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("MedicationService.getAllMedications")
    public List<Medication> getAllMedications() {
        log.debug("Fetching all medications");
        try {
            List<Medication> list = medicationRepository.findAll();
            Span.current().setAttribute("medications.count", list.size());
            log.info("Retrieved {} medications", list.size()); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching all medications: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("MedicationService.searchMedications")
    public List<Medication> searchMedications(@SpanAttribute("medication.query") String query) {
        log.info("Searching medications query='{}'", query);
        try {
            List<Medication> list = medicationRepository.findByMedicationNameContainingIgnoreCase(query);
            Span.current().setAttribute("medications.results", list.size());
            log.info("Medication search returned {} results for query='{}'", list.size(), query); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error searching medications query='{}': {}", query, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("MedicationService.updateMedication")
    public Medication updateMedication(Medication medication) {
        Span.current().setAttribute("medication.id", medication.getId() != null ? medication.getId() : -1L);
        log.info("Updating medication id={}", medication.getId());
        try {
            Medication updated = medicationRepository.save(medication);
            log.info("Medication updated id={} name={}", updated.getId(), updated.getMedicationName()); return updated;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to update medication id={}: {}", medication.getId(), e.getMessage(), e); throw e;
        }
    }

    @WithSpan("MedicationService.deleteMedication")
    public void deleteMedication(@SpanAttribute("medication.id") Long id) {
        log.info("Deleting medication id={}", id);
        try {
            medicationRepository.deleteById(id); log.info("Medication deleted id={}", id);
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to delete medication id={}: {}", id, e.getMessage(), e); throw e;
        }
    }
}
