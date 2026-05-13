{{/*

 Copyright 2026 The OKDP Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

*/}}

{{- define "polaris-admin.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "polaris-admin.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "polaris-admin.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "polaris-admin.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name (.Chart.Version | replace "+" "_") }}
app.kubernetes.io/name: {{ include "polaris-admin.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "polaris-bootstrap.fullname" -}}
{{- printf "%s-bootstrap" (include "polaris-admin.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "polaris-bootstrap.labels" -}}
{{ include "polaris-admin.labels" . }}
app.kubernetes.io/component: bootstrap
{{- end -}}

{{- define "polaris-principals.fullname" -}}
{{- printf "%s-principals" (include "polaris-admin.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "polaris-principals.labels" -}}
{{ include "polaris-admin.labels" . }}
app.kubernetes.io/component: principals
{{- end -}}
