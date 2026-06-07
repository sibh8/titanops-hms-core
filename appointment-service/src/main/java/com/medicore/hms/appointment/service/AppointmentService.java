package com.medicore.hms.appointment.service;

import com.medicore.hms.appointment.model.Appointment;
import com.medicore.hms.appointment.repository.AppointmentRepository;
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
public class AppointmentService {

    private static final Logger log = LoggerFactory.getLogger(AppointmentService.class);

    @Autowired
    private AppointmentRepository appointmentRepository;

    @Autowired
    private MeterRegistry meterRegistry;

    private Counter appointmentBookings;
    private Counter appointmentCancellations;
    private Counter appointmentCompletions;
    private Counter appointmentNoShows;

    @PostConstruct
    public void initMetrics() {
        appointmentBookings = Counter.builder("medicore.appointment.bookings.total")
                .description("Total number of appointment bookings")
                .tag("service", "appointment-service")
                .register(meterRegistry);

        appointmentCancellations = Counter.builder("medicore.appointment.cancellations.total")
                .description("Total number of appointment cancellations")
                .tag("service", "appointment-service")
                .register(meterRegistry);

        appointmentCompletions = Counter.builder("medicore.appointment.completions.total")
                .description("Total number of completed appointments")
                .tag("service", "appointment-service")
                .register(meterRegistry);

        appointmentNoShows = Counter.builder("medicore.appointment.noshows.total")
                .description("Total number of no-show appointments")
                .tag("service", "appointment-service")
                .register(meterRegistry);

        Gauge.builder("medicore.appointment.active.count", appointmentRepository, repo -> {
                    try {
                        return repo.count();
                    } catch (Exception e) {
                        return 0;
                    }
                })
                .description("Total number of active appointments")
                .tag("service", "appointment-service")
                .register(meterRegistry);
    }

    @WithSpan("AppointmentService.createAppointment")
    public Appointment createAppointment(Appointment appointment) {
        Span span = Span.current();
        span.setAttribute("appointment.patientId", appointment.getPatientId() != null ? appointment.getPatientId() : -1L);
        span.setAttribute("appointment.doctorId",  appointment.getDoctorId()  != null ? appointment.getDoctorId()  : -1L);
        log.info("Creating appointment for patientId={} doctorId={}", appointment.getPatientId(), appointment.getDoctorId());
        try {
            Appointment saved = appointmentRepository.save(appointment);
            span.setAttribute("appointment.id", saved.getId());
            appointmentBookings.increment(); // Increment business metric
            log.info("Appointment created id={}", saved.getId());
            return saved;
        } catch (Exception e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to create appointment: {}", e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("AppointmentService.getAppointmentById")
    public Optional<Appointment> getAppointmentById(@SpanAttribute("appointment.id") Long id) {
        log.debug("Fetching appointment id={}", id);
        try {
            Optional<Appointment> result = appointmentRepository.findById(id);
            Span.current().setAttribute("appointment.found", result.isPresent());
            log.info("Appointment lookup id={} found={}", id, result.isPresent());
            return result;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching appointment id={}: {}", id, e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("AppointmentService.getAllAppointments")
    public List<Appointment> getAllAppointments() {
        log.debug("Fetching all appointments");
        try {
            List<Appointment> list = appointmentRepository.findAll();
            Span.current().setAttribute("appointments.count", list.size());
            log.info("Retrieved {} appointments", list.size());
            return list;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching all appointments: {}", e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("AppointmentService.updateAppointment")
    public Appointment updateAppointment(Appointment appointment) {
        Span.current().setAttribute("appointment.id", appointment.getId() != null ? appointment.getId() : -1L);
        log.info("Updating appointment id={}", appointment.getId());
        try {
            Appointment updated = appointmentRepository.save(appointment);
            log.info("Appointment updated id={}", updated.getId());
            return updated;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to update appointment id={}: {}", appointment.getId(), e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("AppointmentService.deleteAppointment")
    public void deleteAppointment(@SpanAttribute("appointment.id") Long id) {
        log.info("Deleting appointment id={}", id);
        try {
            appointmentRepository.deleteById(id);
            log.info("Appointment deleted id={}", id);
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to delete appointment id={}: {}", id, e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("AppointmentService.getAppointmentsByPatientId")
    public List<Appointment> getAppointmentsByPatientId(@SpanAttribute("patient.id") Long patientId) {
        log.info("Fetching appointments for patientId={}", patientId);
        try {
            List<Appointment> list = appointmentRepository.findByPatientId(patientId);
            Span.current().setAttribute("appointments.count", list.size());
            log.info("Found {} appointments for patientId={}", list.size(), patientId);
            return list;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching appointments for patientId={}: {}", patientId, e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("AppointmentService.getAppointmentsByProviderId")
    public List<Appointment> getAppointmentsByProviderId(@SpanAttribute("provider.id") Long providerId) {
        log.info("Fetching appointments for providerId={}", providerId);
        try {
            List<Appointment> list = appointmentRepository.findByDoctorId(providerId);
            Span.current().setAttribute("appointments.count", list.size());
            log.info("Found {} appointments for providerId={}", list.size(), providerId);
            return list;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching appointments for providerId={}: {}", providerId, e.getMessage(), e);
            throw e;
        }
    }

    @WithSpan("AppointmentService.updateAppointmentStatus")
    public Appointment updateAppointmentStatus(@SpanAttribute("appointment.id") Long id, @SpanAttribute("appointment.status") String status) {
        log.info("Updating status for appointment id={} to status={}", id, status);
        try {
            Optional<Appointment> existing = appointmentRepository.findById(id);
            if (existing.isEmpty()) {
                throw new RuntimeException("Appointment not found id=" + id);
            }
            Appointment appt = existing.get();
            appt.setStatus(status);
            
            // Track business metrics based on status
            if ("CANCELLED".equalsIgnoreCase(status)) {
                appointmentCancellations.increment();
            } else if ("COMPLETED".equalsIgnoreCase(status)) {
                appointmentCompletions.increment();
            } else if ("NO_SHOW".equalsIgnoreCase(status)) {
                appointmentNoShows.increment();
            }
            
            Appointment updated = appointmentRepository.save(appt);
            log.info("Appointment id={} status updated to {}", id, status);
            return updated;
        } catch (Exception e) {
            Span.current().recordException(e);
            Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to update status for appointment id={}: {}", id, e.getMessage(), e);
            throw e;
        }
    }
}
