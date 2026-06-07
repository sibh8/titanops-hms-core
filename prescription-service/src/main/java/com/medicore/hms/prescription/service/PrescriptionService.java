package com.medicore.hms.prescription.service;

import com.medicore.hms.prescription.model.Prescription;
import com.medicore.hms.prescription.model.PrescriptionItem;
import com.medicore.hms.prescription.repository.PrescriptionRepository;
import com.medicore.hms.prescription.repository.PrescriptionItemRepository;
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
import java.util.Date;
import java.util.List;
import java.util.Optional;

@Service
public class PrescriptionService {

    private static final Logger log = LoggerFactory.getLogger(PrescriptionService.class);

    @Autowired private PrescriptionRepository prescriptionRepository;
    @Autowired private PrescriptionItemRepository prescriptionItemRepository;
    @Autowired private MeterRegistry meterRegistry;

    private Counter prescriptionsIssued;
    private Counter prescriptionItems;

    @PostConstruct
    public void initMetrics() {
        prescriptionsIssued = Counter.builder("medicore.prescription.issued.total")
                .description("Total number of prescriptions issued")
                .tag("service", "prescription-service")
                .register(meterRegistry);

        prescriptionItems = Counter.builder("medicore.prescription.items.total")
                .description("Total number of prescription items")
                .tag("service", "prescription-service")
                .register(meterRegistry);

        Gauge.builder("medicore.prescription.active.count", prescriptionRepository, repo -> {
                    try {
                        return repo.count();
                    } catch (Exception e) {
                        return 0;
                    }
                })
                .description("Total number of active prescriptions")
                .tag("service", "prescription-service")
                .register(meterRegistry);
    }

    @WithSpan("PrescriptionService.createPrescription")
    public Prescription createPrescription(Prescription prescription) {
        Span span = Span.current();
        span.setAttribute("prescription.patientId",  prescription.getPatientId()  != null ? prescription.getPatientId()  : -1L);
        span.setAttribute("prescription.providerId", prescription.getProviderId() != null ? prescription.getProviderId() : -1L);
        log.info("Creating prescription for patientId={} providerId={}", prescription.getPatientId(), prescription.getProviderId());
        try {
            prescription.setPrescriptionDate(new Date());
            Prescription saved = prescriptionRepository.save(prescription);
            span.setAttribute("prescription.id", saved.getId());
            prescriptionsIssued.increment(); // Increment business metric
            log.info("Prescription created id={}", saved.getId()); return saved;
        } catch (Exception e) {
            span.recordException(e); span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to create prescription: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("PrescriptionService.getPrescriptionById")
    public Optional<Prescription> getPrescriptionById(@SpanAttribute("prescription.id") Long id) {
        log.debug("Fetching prescription id={}", id);
        try {
            Optional<Prescription> result = prescriptionRepository.findById(id);
            Span.current().setAttribute("prescription.found", result.isPresent());
            log.info("Prescription lookup id={} found={}", id, result.isPresent()); return result;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching prescription id={}: {}", id, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("PrescriptionService.getAllPrescriptions")
    public List<Prescription> getAllPrescriptions() {
        log.debug("Fetching all prescriptions");
        try {
            List<Prescription> list = prescriptionRepository.findAll();
            Span.current().setAttribute("prescriptions.count", list.size());
            log.info("Retrieved {} prescriptions", list.size()); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching prescriptions: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("PrescriptionService.getPrescriptionsByPatientId")
    public List<Prescription> getPrescriptionsByPatientId(@SpanAttribute("patient.id") Long patientId) {
        log.debug("Fetching prescriptions for patientId={}", patientId);
        try {
            List<Prescription> list = prescriptionRepository.findByPatientId(patientId);
            Span.current().setAttribute("prescriptions.count", list.size());
            log.info("Retrieved {} prescriptions for patientId={}", list.size(), patientId); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching prescriptions patientId={}: {}", patientId, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("PrescriptionService.updatePrescription")
    public Prescription updatePrescription(Prescription prescription) {
        Span.current().setAttribute("prescription.id", prescription.getId() != null ? prescription.getId() : -1L);
        log.info("Updating prescription id={}", prescription.getId());
        try {
            Prescription updated = prescriptionRepository.save(prescription);
            log.info("Prescription updated id={}", updated.getId()); return updated;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to update prescription id={}: {}", prescription.getId(), e.getMessage(), e); throw e;
        }
    }

    @WithSpan("PrescriptionService.deletePrescription")
    public void deletePrescription(@SpanAttribute("prescription.id") Long id) {
        log.info("Deleting prescription id={}", id);
        try {
            prescriptionRepository.deleteById(id); log.info("Prescription deleted id={}", id);
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to delete prescription id={}: {}", id, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("PrescriptionService.addPrescriptionItem")
    public PrescriptionItem addPrescriptionItem(PrescriptionItem item) {
        Span span = Span.current();
        span.setAttribute("prescriptionItem.prescriptionId", item.getPrescriptionId() != null ? item.getPrescriptionId() : -1L);
        span.setAttribute("prescriptionItem.medicationId",   item.getMedicationId()   != null ? item.getMedicationId()   : -1L);
        log.info("Adding prescription item prescriptionId={} medicationId={}", item.getPrescriptionId(), item.getMedicationId());
        try {
            PrescriptionItem saved = prescriptionItemRepository.save(item);
            span.setAttribute("prescriptionItem.id", saved.getId());
            log.info("Prescription item added id={}", saved.getId()); return saved;
        } catch (Exception e) {
            span.recordException(e); span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to add prescription item: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("PrescriptionService.getItemsByPrescriptionId")
    public List<PrescriptionItem> getItemsByPrescriptionId(@SpanAttribute("prescription.id") Long prescriptionId) {
        log.debug("Fetching items for prescriptionId={}", prescriptionId);
        try {
            List<PrescriptionItem> list = prescriptionItemRepository.findByPrescriptionId(prescriptionId);
            Span.current().setAttribute("prescriptionItems.count", list.size());
            log.info("Retrieved {} items for prescriptionId={}", list.size(), prescriptionId); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching items for prescriptionId={}: {}", prescriptionId, e.getMessage(), e); throw e;
        }
    }
}
