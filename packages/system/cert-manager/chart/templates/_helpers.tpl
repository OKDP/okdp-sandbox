{{/*
Expand the name of the chart.
*/}}
{{- define "cert-issuers.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cert-issuers.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cert-issuers.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cert-issuers.labels" -}}
helm.sh/chart: {{ include "cert-issuers.chart" . }}
{{ include "cert-issuers.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cert-issuers.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cert-issuers.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Get the certificate namespace - use global setting or release namespace
*/}}
{{- define "cert-issuers.certificateNamespace" -}}
{{- if .Values.global.certificateNamespace }}
{{- .Values.global.certificateNamespace }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Validate CA cluster issuer configuration
*/}}
{{- define "cert-issuers.validateCAIssuer" -}}
{{- if not .name }}
{{- fail "CA ClusterIssuer name is required" }}
{{- end }}
{{- if not .ca_crt }}
{{- fail (printf "CA certificate (ca_crt) is required for issuer '%s'" .name) }}
{{- end }}
{{- end }}

{{/*
Validate self-signed cluster issuer configuration
*/}}
{{- define "cert-issuers.validateSelfSignedIssuer" -}}
{{- if not .name }}
{{- fail "Self-signed ClusterIssuer name is required" }}
{{- end }}
{{- end }}

{{/*
Get replication annotations based on method
*/}}
{{- define "cert-issuers.replicationAnnotations" -}}
{{- $ctx := index . 0 }}
{{- $name := index . 1 }}
{{- if $ctx.Values.replication.enabled }}
{{- if eq $ctx.Values.replication.method "kubed" }}
kubed.appscode.com/sync: ca/{{ $name }}=copy
{{- else if eq $ctx.Values.replication.method "replicator" }}
replicator.v1.mittwald.de/replication-allowed: "true"
replicator.v1.mittwald.de/replication-allowed-namespaces: {{ $ctx.Values.replication.allowedNamespaces | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Get certificate configuration with defaults
*/}}
{{- define "cert-issuers.certificateConfig" -}}
{{- $defaults := dict "commonName" "Self-Signed CA" "organization" "OKDP" "country" "US" "validity" "8760h" "algorithm" "ECDSA" "size" 256 }}
{{- if .certificate }}
{{- $config := mergeOverwrite $defaults .certificate }}
{{- toYaml $config }}
{{- else }}
{{- toYaml $defaults }}
{{- end }}
{{- end }} 