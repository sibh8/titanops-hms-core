package com.medicore.hms.patient.service;

import com.medicore.hms.patient.model.Patient;
import com.medicore.hms.patient.repository.PatientRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.instrumentation.annotations.SpanAttribute;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import javax.annotation.PostConstruct;
import java.util.List;
import java.util.Optional;

@Service
public class PatientService {

    private static final Logger log = LoggerFactory.getLogger(PatientService.class);

    @Autowired
    private PatientRepository patientRepository;

    @Autowired
    private MeterRegistry meterRegistry;

    private Counter patientRegistrations;
    private Counter patientUpdates;
    private Counter patientSearches;

    @PostConstruct
    public void initMetrics() {
        // Business metrics
        patientRegistrations = Counter.builder("medicore.patient.registrations.total")
                .description("Total number of patient registrations")
                .tag("service", "patient-service")
                .register(meterRegistry);

        patientUpdates = Counter.builder("medicore.patient.updates.total")
                .description("Total number of patient updates")
                .tag("service", "patient-service")
                .register(meterRegistry);

        patientSearches = Counter.builder("medicore.patient.searches.total")
                .description("Total number of patient searches")
                .tag("service", "patient-service")
                .register(meterRegistry);

        // Active patients gauge
        Gauge.builder("medicore.patient.active.count", patientRepository, repo -> {
                    try {
                        return repo.count();
                    } catch (Exception e) {
                        return 0;
                    }
                })
                .description("Total number of active patients")
                .tag("service", "patient-service")
                .register(meterRegistry);
    }

    @WithSpan("PatientService.createPatient")
    public Patient createPatient(Patient patient) {
        Span span = Span.current();
        span.setAttribute("patient.firstName", patient.getFirstName() != null ? patient.getFirstName() : "");
        span.setAttribute("patient.lastName",  patient.getLastName()  != null ? patient.getLastName()  : "");
        log.info("Creating patient: {} {}", patient.getFirstName(), patient.getLastName());
        try {
            Patient saved = patientRepository.save(patient);
            span.setAttribute("patient.id", saved.getId());
            patientRegistrations.increment(); // Increment business metric
            log.info("Patient created successfully with id={}", saved.getId());
            return saved;
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to create patient: {}", e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("PatientService.getPatientById")
    public Optional<Patient> getPatientById(@SpanAttribute("patient.id") Long id) {
        log.debug("Fetching patient id={}", id);
        try {
            Optional<Patient> result = patientRepository.findById(id);
            Span.current().setAttribute("patient.found", result.isPresent());
            log.info("Patient lookup id={} found={}", id, result.isPresent());
            return result;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching patient id={}: {}", id, e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("PatientService.getAllPatients")
    public List<Patient> getAllPatients() {
        log.debug("Fetching all patients");
        try {
            List<Patient> patients = patientRepository.findAll();
            Span.current().setAttribute("patients.count", patients.size());
            log.info("Retrieved {} patients", patients.size());
            return patients;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching all patients: {}", e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("PatientService.updatePatient")
    public Patient updatePatient(Patient patient) {
        Span span = Span.current();
        span.setAttribute("patient.id", patient.getId() != null ? patient.getId() : -1L);
        log.info("Updating patient id={}", patient.getId());
        try {
            Patient updated = patientRepository.save(patient);
            patientUpdates.increment(); // Increment business metric
            log.info("Patient updated successfully id={}", updated.getId());
            return updated;
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to update patient id={}: {}", patient.getId(), e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("PatientService.searchPatients")
    public List<Patient> searchPatients(@SpanAttribute("search.query") String query) {
        log.info("Searching patients with query='{}'", query);
        try {
            patientSearches.increment(); // Increment business metric
            String q = query != null ? query.toLowerCase() : "";
            List<Patient> patients = patientRepository.findByFirstNameContainingIgnoreCaseOrLastNameContainingIgnoreCase(q, q);
            Span.current().setAttribute("patients.count", patients.size());
            log.info("Search for '{}' returned {} results", query, patients.size());
            return patients;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error searching patients: {}", e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("PatientService.deletePatient")
    public void deletePatient(@SpanAttribute("patient.id") Long id) {
        log.info("Deleting patient id={}", id);
        try {
            patientRepository.deleteById(id);
            log.info("Patient deleted id={}", id);
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to delete patient id={}: {}", id, e.getMessage(), e);
            throw e;
        }
    }
}
