/**
 * telemetry.js — OpenTelemetry browser instrumentation for medicore-hms-ui
 *
 * Traces  → OTLP/HTTP  → /otel/v1/traces   (nginx proxies to otel-collector:4318)
 * Metrics → OTLP/HTTP  → /otel/v1/metrics  (same)
 *
 * Auto-instrumented:
 *   - Document load (page load timings)
 *   - Fetch API calls (all /api/* calls, traceparent header injected)
 *   - XMLHttpRequest
 *   - User interactions (click events)
 */

import { WebTracerProvider, BatchSpanProcessor } from '@opentelemetry/sdk-trace-web';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { MeterProvider, PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { registerInstrumentations } from '@opentelemetry/instrumentation';
import { FetchInstrumentation } from '@opentelemetry/instrumentation-fetch';
import { XMLHttpRequestInstrumentation } from '@opentelemetry/instrumentation-xml-http-request';
import { DocumentLoadInstrumentation } from '@opentelemetry/instrumentation-document-load';
import { UserInteractionInstrumentation } from '@opentelemetry/instrumentation-user-interaction';
import { W3CTraceContextPropagator } from '@opentelemetry/core';
import { context, propagation, trace, metrics } from '@opentelemetry/api';

// ─── Resource ────────────────────────────────────────────────────────────────
const resource = new Resource({
  'service.name':    'medicore-hms-ui',
  'service.version': '1.0.0',
  'deployment.environment': import.meta.env.MODE || 'production',
});

// ─── Propagator ──────────────────────────────────────────────────────────────
propagation.setGlobalPropagator(new W3CTraceContextPropagator());

// ─── Trace exporter ──────────────────────────────────────────────────────────
// /otel/ is proxied by nginx → otel-collector:4318 (OTLP/HTTP)
const traceExporter = new OTLPTraceExporter({
  url: '/otel/v1/traces',
  headers: {},
});

const tracerProvider = new WebTracerProvider({ resource });
tracerProvider.addSpanProcessor(new BatchSpanProcessor(traceExporter, {
  maxQueueSize:       512,
  maxExportBatchSize: 64,
  scheduledDelayMillis: 5000,
}));
tracerProvider.register();

// ─── Metrics exporter ────────────────────────────────────────────────────────
const metricExporter = new OTLPMetricExporter({
  url: '/otel/v1/metrics',
  headers: {},
});

const meterProvider = new MeterProvider({
  resource,
  readers: [
    new PeriodicExportingMetricReader({
      exporter: metricExporter,
      exportIntervalMillis: 30_000, // export every 30 s
    }),
  ],
});
metrics.setGlobalMeterProvider(meterProvider);

// ─── Custom metrics ──────────────────────────────────────────────────────────
const meter = metrics.getMeter('medicore-hms-ui');

export const apiCallCounter    = meter.createCounter('ui.api.calls',    { description: 'Total API calls made from the UI' });
export const apiErrorCounter   = meter.createCounter('ui.api.errors',   { description: 'Total API call errors' });
export const pageViewCounter   = meter.createCounter('ui.page.views',   { description: 'Page view counter' });
export const apiLatencyHisto   = meter.createHistogram('ui.api.latency_ms', { description: 'API response latency in ms', unit: 'ms' });

// ─── Auto-instrumentations ───────────────────────────────────────────────────
registerInstrumentations({
  tracerProvider,
  instrumentations: [
    new DocumentLoadInstrumentation(),

    new UserInteractionInstrumentation({
      eventNames: ['click'],
    }),

    new FetchInstrumentation({
      // Inject traceparent into all same-origin /api/* calls so backend spans
      // link up in Jaeger under the same trace.
      propagateTraceHeaderCorsUrls: [/\/api\/.*/],
      clearTimingResources: true,
      applyCustomAttributesOnSpan(span, request, result) {
        span.setAttribute('http.request.url', typeof request === 'string' ? request : request.url);
        if (result instanceof Response) {
          span.setAttribute('http.response.status_code', result.status);
        }
        // Record custom metrics alongside each fetch span
        apiCallCounter.add(1, { url: typeof request === 'string' ? request : request.url });
      },
    }),

    new XMLHttpRequestInstrumentation({
      propagateTraceHeaderCorsUrls: [/\/api\/.*/],
    }),
  ],
});

// ─── Tracer export (for manual spans) ────────────────────────────────────────
export const tracer = trace.getTracer('medicore-hms-ui');

export default tracerProvider;
