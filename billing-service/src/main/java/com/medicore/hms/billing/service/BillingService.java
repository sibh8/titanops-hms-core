package com.medicore.hms.billing.service;

import com.medicore.hms.billing.model.Invoice;
import com.medicore.hms.billing.repository.InvoiceRepository;
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
import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

@Service
public class BillingService {

    private static final Logger log = LoggerFactory.getLogger(BillingService.class);

    @Autowired
    private InvoiceRepository invoiceRepository;

    @Autowired
    private MeterRegistry meterRegistry;

    private Counter invoicesCreated;
    private Counter invoicesPaid;

    @PostConstruct
    public void initMetrics() {
        invoicesCreated = Counter.builder("medicore.billing.invoices.created.total")
                .description("Total number of invoices created")
                .tag("service", "billing-service")
                .register(meterRegistry);

        invoicesPaid = Counter.builder("medicore.billing.invoices.paid.total")
                .description("Total number of invoices paid")
                .tag("service", "billing-service")
                .register(meterRegistry);

        Gauge.builder("medicore.billing.invoices.pending.count", invoiceRepository, repo -> {
                    try {
                        return repo.findAll().stream()
                                .filter(inv -> "PENDING".equalsIgnoreCase(inv.getStatus()))
                                .count();
                    } catch (Exception e) {
                        return 0;
                    }
                })
                .description("Number of pending invoices")
                .tag("service", "billing-service")
                .register(meterRegistry);

        Gauge.builder("medicore.billing.revenue.total", invoiceRepository, repo -> {
                    try {
                        return repo.findAll().stream()
                                .filter(inv -> "PAID".equalsIgnoreCase(inv.getStatus()))
                                .map(Invoice::getTotalAmount)
                                .reduce(0.0, Double::sum);
                    } catch (Exception e) {
                        return 0.0;
                    }
                })
                .description("Total revenue from paid invoices")
                .tag("service", "billing-service")
                .register(meterRegistry);
    }

    @WithSpan("BillingService.createInvoice")
    public Invoice createInvoice(Invoice invoice) {
        Span span = Span.current();
        span.setAttribute("invoice.patientId",   invoice.getPatientId()   != null ? invoice.getPatientId()   : -1L);
        span.setAttribute("invoice.encounterId", invoice.getEncounterId() != null ? invoice.getEncounterId() : -1L);
        log.info("Creating invoice for patientId={} encounterId={}", invoice.getPatientId(), invoice.getEncounterId());
        try {
            Invoice saved = invoiceRepository.save(invoice);
            span.setAttribute("invoice.id", saved.getId());
            invoicesCreated.increment(); // Increment business metric
            log.info("Invoice created id={} status={}", saved.getId(), saved.getStatus());
            return saved;
        } catch (Exception e) {
            span.recordException(e); span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to create invoice: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("BillingService.getInvoiceById")
    public Optional<Invoice> getInvoiceById(@SpanAttribute("invoice.id") Long id) {
        log.debug("Fetching invoice id={}", id);
        try {
            Optional<Invoice> result = invoiceRepository.findById(id);
            Span.current().setAttribute("invoice.found", result.isPresent());
            log.info("Invoice lookup id={} found={}", id, result.isPresent());
            return result;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching invoice id={}: {}", id, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("BillingService.getAllInvoices")
    public List<Invoice> getAllInvoices() {
        log.debug("Fetching all invoices");
        try {
            List<Invoice> list = invoiceRepository.findAll();
            Span.current().setAttribute("invoices.count", list.size());
            log.info("Retrieved {} invoices", list.size()); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching all invoices: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("BillingService.getInvoicesByPatientId")
    public List<Invoice> getInvoicesByPatientId(@SpanAttribute("patient.id") Long patientId) {
        log.debug("Fetching invoices for patientId={}", patientId);
        try {
            List<Invoice> list = invoiceRepository.findByPatientId(patientId);
            Span.current().setAttribute("invoices.count", list.size());
            log.info("Retrieved {} invoices for patientId={}", list.size(), patientId); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching invoices for patientId={}: {}", patientId, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("BillingService.updateInvoice")
    public Invoice updateInvoice(Invoice invoice) {
        Span.current().setAttribute("invoice.id", invoice.getId() != null ? invoice.getId() : -1L);
        log.info("Updating invoice id={}", invoice.getId());
        try {
            Invoice updated = invoiceRepository.save(invoice);
            // Track paid invoices
            if ("PAID".equalsIgnoreCase(updated.getStatus())) {
                invoicesPaid.increment();
            }
            log.info("Invoice updated id={} status={}", updated.getId(), updated.getStatus()); return updated;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to update invoice id={}: {}", invoice.getId(), e.getMessage(), e); throw e;
        }
    }

    @WithSpan("BillingService.deleteInvoice")
    public void deleteInvoice(@SpanAttribute("invoice.id") Long id) {
        log.info("Deleting invoice id={}", id);
        try {
            invoiceRepository.deleteById(id); log.info("Invoice deleted id={}", id);
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to delete invoice id={}: {}", id, e.getMessage(), e); throw e;
        }
    }
}
