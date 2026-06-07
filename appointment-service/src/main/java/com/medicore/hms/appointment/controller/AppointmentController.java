package com.medicore.hms.appointment.controller;

import com.medicore.hms.appointment.model.Appointment;
import com.medicore.hms.appointment.service.AppointmentService;
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
@RequestMapping("/api/appointments")
public class AppointmentController {

    private static final Logger log = LoggerFactory.getLogger(AppointmentController.class);

    @Autowired
    private AppointmentService appointmentService;

    @PostMapping
    @WithSpan("AppointmentController.createAppointment")
    public ResponseEntity<Appointment> createAppointment(@RequestBody Appointment appointment) {
        log.info("POST /api/appointments patientId={} providerId={}", appointment.getPatientId(), appointment.getProviderId());
        try {
            Appointment saved = appointmentService.createAppointment(appointment);
            log.info("POST /api/appointments -> 201 id={}", saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            log.error("POST /api/appointments failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}")
    @WithSpan("AppointmentController.getAppointmentById")
    public ResponseEntity<Appointment> getAppointmentById(@PathVariable @SpanAttribute("appointment.id") Long id) {
        log.info("GET /api/appointments/{}", id);
        try {
            Optional<Appointment> appt = appointmentService.getAppointmentById(id);
            if (appt.isPresent()) { log.info("GET /api/appointments/{} -> 200", id); return ResponseEntity.ok(appt.get()); }
            log.warn("GET /api/appointments/{} -> 404", id); return ResponseEntity.notFound().build();
        } catch (Exception e) {
            log.error("GET /api/appointments/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping
    @WithSpan("AppointmentController.getAllAppointments")
    public ResponseEntity<List<Appointment>> getAllAppointments() {
        log.info("GET /api/appointments");
        try {
            List<Appointment> list = appointmentService.getAllAppointments();
            log.info("GET /api/appointments -> 200 count={}", list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/appointments failed: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/patient/{patientId}")
    @WithSpan("AppointmentController.getByPatientId")
    public ResponseEntity<List<Appointment>> getByPatientId(@PathVariable @SpanAttribute("patient.id") Long patientId) {
        log.info("GET /api/appointments/patient/{}", patientId);
        try {
            List<Appointment> list = appointmentService.getAppointmentsByPatientId(patientId);
            log.info("GET /api/appointments/patient/{} -> 200 count={}", patientId, list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/appointments/patient/{} failed: {}", patientId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/provider/{providerId}")
    @WithSpan("AppointmentController.getByProviderId")
    public ResponseEntity<List<Appointment>> getByProviderId(@PathVariable @SpanAttribute("provider.id") Long providerId) {
        log.info("GET /api/appointments/provider/{}", providerId);
        try {
            List<Appointment> list = appointmentService.getAppointmentsByProviderId(providerId);
            log.info("GET /api/appointments/provider/{} -> 200 count={}", providerId, list.size());
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            log.error("GET /api/appointments/provider/{} failed: {}", providerId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{id}")
    @WithSpan("AppointmentController.updateAppointment")
    public ResponseEntity<Appointment> updateAppointment(@PathVariable @SpanAttribute("appointment.id") Long id, @RequestBody Appointment appointment) {
        log.info("PUT /api/appointments/{}", id);
        try {
            appointment.setId(id);
            Appointment updated = appointmentService.updateAppointment(appointment);
            log.info("PUT /api/appointments/{} -> 200", id);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            log.error("PUT /api/appointments/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{id}/status")
    @WithSpan("AppointmentController.updateStatus")
    public ResponseEntity<Appointment> updateStatus(@PathVariable @SpanAttribute("appointment.id") Long id, @RequestParam @SpanAttribute("appointment.status") String status) {
        log.info("PUT /api/appointments/{}/status status={}", id, status);
        try {
            Appointment updated = appointmentService.updateAppointmentStatus(id, status);
            log.info("PUT /api/appointments/{}/status -> 200 status={}", id, status);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            log.error("PUT /api/appointments/{}/status failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/{id}")
    @WithSpan("AppointmentController.deleteAppointment")
    public ResponseEntity<Void> deleteAppointment(@PathVariable @SpanAttribute("appointment.id") Long id) {
        log.info("DELETE /api/appointments/{}", id);
        try {
            appointmentService.deleteAppointment(id);
            log.info("DELETE /api/appointments/{} -> 204", id);
            return ResponseEntity.noContent().build();
        } catch (Exception e) {
            log.error("DELETE /api/appointments/{} failed: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
