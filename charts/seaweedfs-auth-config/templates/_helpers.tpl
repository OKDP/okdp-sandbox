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

{{- define "seaweedfs-auth-config.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "seaweedfs-auth-config.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "seaweedfs-auth-config.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "seaweedfs-auth-config.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name (.Chart.Version | replace "+" "_") }}
app.kubernetes.io/name: {{ include "seaweedfs-auth-config.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "seaweedfs-auth-config.lookupSecretDataB64dec" -}}
{{- $ns := .namespace -}}
{{- $secretName := .secretName -}}
{{- $key := .key -}}
{{- $s := lookup "v1" "Secret" $ns $secretName -}}
{{- if not $s -}}
{{- fail (printf "seaweedfs-auth-config: required Secret %q not found in namespace %q" $secretName $ns) -}}
{{- end -}}
{{- $v := index $s.data $key -}}
{{- if not $v -}}
{{- fail (printf "seaweedfs-auth-config: key %q not found in Secret %q (namespace %q)" $key $secretName $ns) -}}
{{- end -}}
{{- $v | b64dec -}}
{{- end -}}

