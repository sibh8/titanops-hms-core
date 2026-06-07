package com.medicore.hms.lab.controller;

import com.medicore.hms.lab.model.LabOrder;
import com.medicore.hms.lab.model.LabResult;
import com.medicore.hms.lab.service.LabService;
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
@RequestMapping("/api/lab")
public class LabController {

    private static final Logger log = LoggerFactory.getLogger(LabController.class);

    @Autowired
    private LabService labService;

    @PostMapping("/orders")
    @WithSpan("LabController.createLabOrder")
    public ResponseEntity<LabOrder> createLabOrder(@RequestBody LabOrder order) {
        log.info("POST /api/lab/orders testName={} patientId={}", order.getTestName(), order.getPatientId());
        try {
            LabOrder saved = labService.createLabOrder(order);
            log.info("POST /api/lab/orders -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("POST /api/lab/orders failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/orders/{id}")
    @WithSpan("LabController.getLabOrderById")
    public ResponseEntity<LabOrder> getLabOrderById(@PathVariable @SpanAttribute("labOrder.id") Long id) {
        log.info("GET /api/lab/orders/{}", id);
        try {
            Optional<LabOrder> order = labService.getLabOrderById(id);
            if (order.isPresent()) { log.info("GET /api/lab/orders/{} -> 200", id); return ResponseEntity.ok(order.get()); }
            log.warn("GET /api/lab/orders/{} -> 404", id); return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("GET /api/lab/orders/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/orders")
    @WithSpan("LabController.getAllLabOrders")
    public ResponseEntity<List<LabOrder>> getAllLabOrders() {
        log.info("GET /api/lab/orders");
        try {
            List<LabOrder> list = labService.getAllLabOrders();
            log.info("GET /api/lab/orders -> 200 count={}", list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/lab/orders failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/orders/pending")
    @WithSpan("LabController.getPendingOrders")
    public ResponseEntity<List<LabOrder>> getPendingOrders() {
        log.info("GET /api/lab/orders/pending");
        try {
            List<LabOrder> list = labService.getPendingLabOrders();
            log.info("GET /api/lab/orders/pending -> 200 count={}", list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/lab/orders/pending failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/orders/patient/{patientId}")
    @WithSpan("LabController.getOrdersByPatientId")
    public ResponseEntity<List<LabOrder>> getOrdersByPatientId(@PathVariable @SpanAttribute("patient.id") Long patientId) {
        log.info("GET /api/lab/orders/patient/{}", patientId);
        try {
            List<LabOrder> list = labService.getLabOrdersByPatientId(patientId);
            log.info("GET /api/lab/orders/patient/{} -> 200 count={}", patientId, list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/lab/orders/patient/{} failed: {}", patientId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/orders/{id}/status")
    @WithSpan("LabController.updateOrderStatus")
    public ResponseEntity<LabOrder> updateOrderStatus(@PathVariable @SpanAttribute("labOrder.id") Long id, @RequestParam @SpanAttribute("labOrder.status") String status) {
        log.info("PUT /api/lab/orders/{}/status status={}", id, status);
        try {
            LabOrder updated = labService.updateLabOrderStatus(id, status);
            log.info("PUT /api/lab/orders/{}/status -> 200", id);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            log.error("PUT /api/lab/orders/{}/status failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/orders/{id}")
    @WithSpan("LabController.deleteLabOrder")
    public ResponseEntity<Void> deleteLabOrder(@PathVariable @SpanAttribute("labOrder.id") Long id) {
        log.info("DELETE /api/lab/orders/{}", id);
        try {
            labService.deleteLabOrder(id);
            log.info("DELETE /api/lab/orders/{} -> 204", id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            log.error("DELETE /api/lab/orders/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/results")
    @WithSpan("LabController.addLabResult")
    public ResponseEntity<LabResult> addLabResult(@RequestBody LabResult result) {
        log.info("POST /api/lab/results labOrderId={}", result.getLabOrderId());
        try {
            LabResult saved = labService.addLabResult(result);
            log.info("POST /api/lab/results -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("POST /api/lab/results failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/results/order/{orderId}")
    @WithSpan("LabController.getResultsByOrderId")
    public ResponseEntity<List<LabResult>> getResultsByOrderId(@PathVariable @SpanAttribute("labOrder.id") Long orderId) {
        log.info("GET /api/lab/results/order/{}", orderId);
        try {
            List<LabResult> list = labService.getLabResultsByOrderId(orderId);
            log.info("GET /api/lab/results/order/{} -> 200 count={}", orderId, list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/lab/results/order/{} failed: {}", orderId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
