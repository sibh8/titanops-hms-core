package com.medicore.hms.lab.service;

import com.medicore.hms.lab.model.LabOrder;
import com.medicore.hms.lab.model.LabResult;
import com.medicore.hms.lab.repository.LabOrderRepository;
import com.medicore.hms.lab.repository.LabResultRepository;
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
public class LabService {

    private static final Logger log = LoggerFactory.getLogger(LabService.class);

    @Autowired private LabOrderRepository labOrderRepository;
    @Autowired private LabResultRepository labResultRepository;
    @Autowired private MeterRegistry meterRegistry;

    private Counter labOrdersCreated;
    private Counter labResultsCompleted;

    @PostConstruct
    public void initMetrics() {
        labOrdersCreated = Counter.builder("medicore.lab.orders.created.total")
                .description("Total number of lab orders created")
                .tag("service", "lab-service")
                .register(meterRegistry);

        labResultsCompleted = Counter.builder("medicore.lab.results.completed.total")
                .description("Total number of lab results completed")
                .tag("service", "lab-service")
                .register(meterRegistry);

        Gauge.builder("medicore.lab.orders.pending.count", labOrderRepository, repo -> {
                    try {
                        return repo.findByStatus("Pending").size();
                    } catch (Exception e) {
                        return 0;
                    }
                })
                .description("Number of pending lab orders")
                .tag("service", "lab-service")
                .register(meterRegistry);
    }

    @WithSpan("LabService.createLabOrder")
    public LabOrder createLabOrder(LabOrder order) {
        Span span = Span.current();
        span.setAttribute("labOrder.patientId", order.getPatientId() != null ? order.getPatientId() : -1L);
        span.setAttribute("labOrder.testName",  order.getTestName()  != null ? order.getTestName()  : "");
        log.info("Creating lab order testName={} patientId={}", order.getTestName(), order.getPatientId());
        try {
            order.setOrderDate(new Date()); order.setStatus("Pending");
            LabOrder saved = labOrderRepository.save(order);
            span.setAttribute("labOrder.id", saved.getId());
            labOrdersCreated.increment(); // Increment business metric
            log.info("Lab order created id={} status=Pending", saved.getId()); return saved;
        } catch (Exception e) {
            span.recordException(e); span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to create lab order: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("LabService.getLabOrderById")
    public Optional<LabOrder> getLabOrderById(@SpanAttribute("labOrder.id") Long id) {
        log.debug("Fetching lab order id={}", id);
        try {
            Optional<LabOrder> result = labOrderRepository.findById(id);
            Span.current().setAttribute("labOrder.found", result.isPresent());
            log.info("Lab order lookup id={} found={}", id, result.isPresent()); return result;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching lab order id={}: {}", id, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("LabService.getAllLabOrders")
    public List<LabOrder> getAllLabOrders() {
        log.debug("Fetching all lab orders");
        try {
            List<LabOrder> list = labOrderRepository.findAll();
            Span.current().setAttribute("labOrders.count", list.size());
            log.info("Retrieved {} lab orders", list.size()); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching lab orders: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("LabService.getPendingLabOrders")
    public List<LabOrder> getPendingLabOrders() {
        log.debug("Fetching pending lab orders");
        try {
            List<LabOrder> list = labOrderRepository.findByStatus("Pending");
            Span.current().setAttribute("labOrders.pending.count", list.size());
            log.info("Retrieved {} pending lab orders", list.size()); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching pending lab orders: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("LabService.getLabOrdersByPatientId")
    public List<LabOrder> getLabOrdersByPatientId(@SpanAttribute("patient.id") Long patientId) {
        log.debug("Fetching lab orders for patientId={}", patientId);
        try {
            List<LabOrder> list = labOrderRepository.findByPatientId(patientId);
            Span.current().setAttribute("labOrders.count", list.size());
            log.info("Retrieved {} lab orders for patientId={}", list.size(), patientId); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching lab orders patientId={}: {}", patientId, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("LabService.updateLabOrderStatus")
    public LabOrder updateLabOrderStatus(@SpanAttribute("labOrder.id") Long id, @SpanAttribute("labOrder.status") String status) {
        log.info("Updating lab order id={} to status={}", id, status);
        try {
            LabOrder o = labOrderRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Lab order not found: " + id));
            o.setStatus(status);
            LabOrder updated = labOrderRepository.save(o);
            log.info("Lab order id={} status updated to {}", id, status); return updated;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to update lab order status id={}: {}", id, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("LabService.deleteLabOrder")
    public void deleteLabOrder(@SpanAttribute("labOrder.id") Long id) {
        log.info("Deleting lab order id={}", id);
        try {
            labOrderRepository.deleteById(id); log.info("Lab order deleted id={}", id);
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to delete lab order id={}: {}", id, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("LabService.addLabResult")
    public LabResult addLabResult(LabResult result) {
        Span span = Span.current();
        span.setAttribute("labResult.labOrderId", result.getLabOrderId() != null ? result.getLabOrderId() : -1L);
        log.info("Adding lab result for labOrderId={}", result.getLabOrderId());
        try {
            result.setResultDate(new Date());
            LabResult saved = labResultRepository.save(result);
            span.setAttribute("labResult.id", saved.getId());
            updateLabOrderStatus(result.getLabOrderId(), "Completed");
            log.info("Lab result added id={} for orderId={}", saved.getId(), result.getLabOrderId()); return saved;
        } catch (Exception e) {
            span.recordException(e); span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to add lab result for orderId={}: {}", result.getLabOrderId(), e.getMessage(), e); throw e;
        }
    }

    @WithSpan("LabService.getLabResultsByOrderId")
    public List<LabResult> getLabResultsByOrderId(@SpanAttribute("labOrder.id") Long labOrderId) {
        log.debug("Fetching lab results for labOrderId={}", labOrderId);
        try {
            List<LabResult> list = labResultRepository.findByLabOrderId(labOrderId);
            Span.current().setAttribute("labResults.count", list.size());
            log.info("Retrieved {} lab results for labOrderId={}", list.size(), labOrderId); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching lab results for orderId={}: {}", labOrderId, e.getMessage(), e); throw e;
        }
    }
}
