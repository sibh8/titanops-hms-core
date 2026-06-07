package com.medicore.hms.billing.controller;

import com.medicore.hms.billing.model.Invoice;
import com.medicore.hms.billing.service.BillingService;
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
@RequestMapping("/api/invoices")
public class BillingController {

    private static final Logger log = LoggerFactory.getLogger(BillingController.class);

    @Autowired
    private BillingService billingService;

    @PostMapping
    @WithSpan("BillingController.createInvoice")
    public ResponseEntity<Invoice> createInvoice(@RequestBody Invoice invoice) {
        log.info("POST /api/invoices patientId={}", invoice.getPatientId());
        try {
            Invoice saved = billingService.createInvoice(invoice);
            log.info("POST /api/invoices -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("POST /api/invoices failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}")
    @WithSpan("BillingController.getInvoiceById")
    public ResponseEntity<Invoice> getInvoiceById(@PathVariable @SpanAttribute("invoice.id") Long id) {
        log.info("GET /api/invoices/{}", id);
        try {
            Optional<Invoice> inv = billingService.getInvoiceById(id);
            if (inv.isPresent()) { log.info("GET /api/invoices/{} -> 200", id); return ResponseEntity.ok(inv.get()); }
            log.warn("GET /api/invoices/{} -> 404", id); return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("GET /api/invoices/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping
    @WithSpan("BillingController.getAllInvoices")
    public ResponseEntity<List<Invoice>> getAllInvoices() {
        log.info("GET /api/invoices");
        try {
            List<Invoice> list = billingService.getAllInvoices();
            log.info("GET /api/invoices -> 200 count={}", list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/invoices failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/patient/{patientId}")
    @WithSpan("BillingController.getByPatientId")
    public ResponseEntity<List<Invoice>> getByPatientId(@PathVariable @SpanAttribute("patient.id") Long patientId) {
        log.info("GET /api/invoices/patient/{}", patientId);
        try {
            List<Invoice> list = billingService.getInvoicesByPatientId(patientId);
            log.info("GET /api/invoices/patient/{} -> 200 count={}", patientId, list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/invoices/patient/{} failed: {}", patientId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{id}")
    @WithSpan("BillingController.updateInvoice")
    public ResponseEntity<Invoice> updateInvoice(@PathVariable @SpanAttribute("invoice.id") Long id, @RequestBody Invoice invoice) {
        log.info("PUT /api/invoices/{}", id);
        try {
            invoice.setId(id);
            Invoice updated = billingService.updateInvoice(invoice);
            log.info("PUT /api/invoices/{} -> 200", id);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            log.error("PUT /api/invoices/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/{id}")
    @WithSpan("BillingController.deleteInvoice")
    public ResponseEntity<Void> deleteInvoice(@PathVariable @SpanAttribute("invoice.id") Long id) {
        log.info("DELETE /api/invoices/{}", id);
        try {
            billingService.deleteInvoice(id);
            log.info("DELETE /api/invoices/{} -> 204", id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            log.error("DELETE /api/invoices/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
