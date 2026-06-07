package com.medicore.hms.provider.service;

import com.medicore.hms.provider.model.Provider;
import com.medicore.hms.provider.repository.ProviderRepository;
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
public class ProviderService {

    private static final Logger log = LoggerFactory.getLogger(ProviderService.class);

    @Autowired
    private ProviderRepository providerRepository;

    @WithSpan("ProviderService.createProvider")
    public Provider createProvider(Provider provider) {
        Span span = Span.current();
        span.setAttribute("provider.firstName",  provider.getFirstName()  != null ? provider.getFirstName()  : "");
        span.setAttribute("provider.lastName",   provider.getLastName()   != null ? provider.getLastName()   : "");
        span.setAttribute("provider.speciality", provider.getSpeciality() != null ? provider.getSpeciality() : "");
        log.info("Creating provider name={} {} speciality={}", provider.getFirstName(), provider.getLastName(), provider.getSpeciality());
        try {
            provider.setActive(true);
            Provider saved = providerRepository.save(provider);
            span.setAttribute("provider.id", saved.getId());
            log.info("Provider created id={} name={} {}", saved.getId(), saved.getFirstName(), saved.getLastName());
            return saved;
        } catch (Exception e) {
            span.recordException(e); span.setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to create provider: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("ProviderService.getProviderById")
    public Optional<Provider> getProviderById(@SpanAttribute("provider.id") Long id) {
        log.debug("Fetching provider id={}", id);
        try {
            Optional<Provider> result = providerRepository.findById(id);
            Span.current().setAttribute("provider.found", result.isPresent());
            log.info("Provider lookup id={} found={}", id, result.isPresent()); return result;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching provider id={}: {}", id, e.getMessage(), e); throw e;
        }
    }

    @WithSpan("ProviderService.getAllProviders")
    public List<Provider> getAllProviders() {
        log.debug("Fetching all providers");
        try {
            List<Provider> list = providerRepository.findAll();
            Span.current().setAttribute("providers.count", list.size());
            log.info("Retrieved {} providers", list.size()); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching all providers: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("ProviderService.getActiveProviders")
    public List<Provider> getActiveProviders() {
        log.debug("Fetching active providers");
        try {
            List<Provider> list = providerRepository.findByActive(true);
            Span.current().setAttribute("providers.active.count", list.size());
            log.info("Retrieved {} active providers", list.size()); return list;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Error fetching active providers: {}", e.getMessage(), e); throw e;
        }
    }

    @WithSpan("ProviderService.updateProvider")
    public Provider updateProvider(Provider provider) {
        Span.current().setAttribute("provider.id", provider.getId() != null ? provider.getId() : -1L);
        log.info("Updating provider id={}", provider.getId());
        try {
            Provider updated = providerRepository.save(provider);
            log.info("Provider updated id={} name={} {}", updated.getId(), updated.getFirstName(), updated.getLastName());
            return updated;
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to update provider id={}: {}", provider.getId(), e.getMessage(), e); throw e;
        }
    }

    @WithSpan("ProviderService.deleteProvider")
    public void deleteProvider(@SpanAttribute("provider.id") Long id) {
        log.info("Deleting provider id={}", id);
        try {
            providerRepository.deleteById(id); log.info("Provider deleted id={}", id);
        } catch (Exception e) {
            Span.current().recordException(e); Span.current().setStatus(StatusCode.ERROR, e.getMessage());
            log.error("Failed to delete provider id={}: {}", id, e.getMessage(), e); throw e;
        }
    }
}
