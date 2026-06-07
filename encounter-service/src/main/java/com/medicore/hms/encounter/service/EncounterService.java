package com.medicore.hms.encounter.service;

import com.medicore.hms.encounter.model.Encounter;
import com.medicore.hms.encounter.repository.EncounterRepository;
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
public class EncounterService {

    private static final Logger log = LoggerFactory.getLogger(EncounterService.class);

    @Autowired
    private EncounterRepository encounterRepository;

    @WithSpan("EncounterService.createEncounter")
    public Encounter createEncounter(Encounter encounter) {
        Span span = Span.current();
        span.setAttribute("encounter.patientId",     encounter.getPatientId()     != null ? encounter.getPatientId()     : -1L);
        span.setAttribute("encounter.providerId",    encounter.getProviderId()    != null ? encounter.getProviderId()    : -1L);
        span.setAttribute("encounter.appointmentId", encounter.getAppointmentId() != null ? encounter.getAppointmentId() : -1L);
        log.info("Creating encounter for patientId={} providerId={}", encounter.getPatientId(), encounter.getProviderId());
        try {
            Encounter saved = encounterRepository.save(encounter);
            span.setAttribute("encounter.id", saved.getId());
            log.info("Encounter created id={} status={}", saved.getId(), saved.getStatus()); return saved;
        } catch (Exception e) {
            span.recordException(e); span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to create encounter: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("EncounterService.getEncounterById")
    public Optional<Encounter> getEncounterById(@SpanAttribute("encounter.id") Long id) {
        log.debug("Fetching encounter id={}", id);
        try {
            Optional<Encounter> result = encounterRepository.findById(id);
            Span.current().setAttribute("encounter.found", result.isPresent());
            log.info("Encounter lookup id={} found={}", id, result.isPresent()); return result;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching encounter id={}: {}", id, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("EncounterService.getAllEncounters")
    public List<Encounter> getAllEncounters() {
        log.debug("Fetching all encounters");
        try {
            List<Encounter> list = encounterRepository.findAll();
            Span.current().setAttribute("encounters.count", list.size());
            log.info("Retrieved {} encounters", list.size()); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching all encounters: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("EncounterService.getEncountersByPatientId")
    public List<Encounter> getEncountersByPatientId(@SpanAttribute("patient.id") Long patientId) {
        log.debug("Fetching encounters for patientId={}", patientId);
        try {
            List<Encounter> list = encounterRepository.findByPatientId(patientId);
            Span.current().setAttribute("encounters.count", list.size());
            log.info("Retrieved {} encounters for patientId={}", list.size(), patientId); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching encounters patientId={}: {}", patientId, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("EncounterService.updateEncounter")
    public Encounter updateEncounter(Encounter encounter) {
        Span.current().setAttribute("encounter.id", encounter.getId() != null ? encounter.getId() : -1L);
        log.info("Updating encounter id={}", encounter.getId());
        try {
            Encounter updated = encounterRepository.save(encounter);
            log.info("Encounter updated id={}", updated.getId()); return updated;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to update encounter id={}: {}", encounter.getId(), e.getMessage(), e); throw e;
        }
    }

    @WithSpan("EncounterService.deleteEncounter")
    public void deleteEncounter(@SpanAttribute("encounter.id") Long id) {
        log.info("Deleting encounter id={}", id);
        try {
            encounterRepository.deleteById(id); log.info("Encounter deleted id={}", id);
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to delete encounter id={}: {}", id, e.getMessage(), e); throw e;
        }
    }
}
