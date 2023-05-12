{{/*
Expand the name of the chart.
*/}}
{{- define "cocov-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cocov-chart.fullname" -}}
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
{{- define "cocov-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "cocov-chart.appVersion" }}
{{- printf "%s" .Chart.AppVersion }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cocov-chart.labels" -}}
helm.sh/chart: {{ include "cocov-chart.chart" . }}
{{ include "cocov-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cocov-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cocov-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cocov-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cocov-chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{ define "sizeInBytes" -}}
{{- if hasSuffix "Mi" . }}
    {{- mulf (float64 (trimSuffix "Mi" .)) 1024 1024 }}
{{- else if hasSuffix "M" (.| quote) }}
    {{- mulf (float64 (trimSuffix "M" .)) 1000 1000 }}
{{- else if hasSuffix "Gi" (.| quote) }}
    {{- mulf (float64 (trimSuffix "Gi" .)) 1024 1024 1024 }}
{{- else if hasSuffix "G" (.| quote) }}
    {{- mulf (float64 (trimSuffix "G" .)) 1000 1000 1000 }}
{{- else if hasSuffix "Ti" (.| quote) }}
    {{- mulf (float64 (trimSuffix "Ti" .)) 1024 1024 1024 1024 }}
{{- else if hasSuffix "T" (.| quote) }}
    {{- mulf (float64 (trimSuffix "T" .)) 1000 1000 1000 1000 }}
{{- else }}
    {{- fail "invalid size definition" -}}
{{- end }}
{{- end }}

{{ define "dockerHubImage" -}}
"registry-1.docker.io/cocov/{{ mustFirst .}}:{{ index . 1 }}"
{{- end }}

{{ define "clusterLocalHost" -}}
{{ include "serviceName" . }}.{{ (index . 1).Release.Namespace }}.svc.cluster.local
{{- end }}

{{ define "serviceName" -}}
{{ include "cocov-chart.fullname" (index . 1) }}-{{ mustFirst . }}
{{- end }}

{{ define "valueOrQuote" -}}
{{ if and (kindIs "map" .) (or .configMapKeyRef .secretKeyRef) -}}
valueFrom:
{{ toYaml . | indent 2 }}
{{- else -}}
value: {{ . | quote }}
{{- end }}
{{- end }}

{{ define "envVar" -}}
- name: {{ mustFirst . }}
{{ include "valueOrQuote" (index . 1) | indent 2 }}
{{- end }}

{{ define "apiEnvs" -}}
{{- $commonKeys := (dict
  "COCOV_GITHUB_APP_ID"                .Values.api.github.app.id
  "COCOV_GITHUB_APP_PRIVATE_KEY"       .Values.api.github.app.privateKey
  "COCOV_GITHUB_APP_INSTALLATION_ID"   .Values.api.github.app.installationID
  "COCOV_GITHUB_WEBHOOK_SECRET_KEY"    .Values.api.github.app.webhookSecret
  "COCOV_GITHUB_OAUTH_CLIENT_ID"       .Values.api.github.app.clientID
  "COCOV_GITHUB_OAUTH_CLIENT_SECRET"   .Values.api.github.app.clientSecret
  "COCOV_DATABASE_USERNAME"            .Values.api.db.username
  "COCOV_DATABASE_PASSWORD"            .Values.api.db.password
  "COCOV_DATABASE_NAME"                .Values.api.db.name
  "COCOV_DATABASE_HOST"                .Values.api.db.host
  "COCOV_DATABASE_PORT"                .Values.api.db.port
  "SECRET_KEY_BASE"                    .Values.api.secretKeyBase
  "COCOV_CRYPTOGRAPHIC_KEY"            .Values.api.cryptoKey
  "COCOV_UI_BASE_URL"                  .Values.ui.externalURL
  "COCOV_ALLOW_OUTSIDE_COLLABORATORS"  .Values.api.github.allowOutsideCollaborators
  "COCOV_REDIS_URL"                    .Values.redis.commonURL
  "COCOV_REDIS_CACHE_URL"              .Values.redis.cacheURL
  "COCOV_SIDEKIQ_REDIS_URL"            .Values.redis.sidekiqURL
) -}}
{{- range $k, $v := $commonKeys -}}
{{ include "envVar" (list $k $v) }}
{{ end }}

{{- if and .Values.storage.local.enabled .Values.storage.s3.enabled -}}
{{ fail "Only a single storage mode must be enabled at a single time. Review configuration for cocov.storage."}}
{{- end -}}
{{- if .Values.storage.s3.enabled -}}
{{ include "envVar" (list "COCOV_GIT_SERVICE_STORAGE_MODE" "s3") }}
{{ include "envVar" (list "COCOV_GIT_SERVICE_S3_STORAGE_BUCKET_NAME" .Values.storage.s3.bucketName) }}
{{- else if .Values.storage.local.enabled -}}
{{ include "envVar" (list "COCOV_GIT_SERVICE_STORAGE_MODE" "local") }}
{{ include "envVar" (list "COCOV_GIT_SERVICE_LOCAL_STORAGE_PATH" .Values.storage.local.mountPath) }}
{{- else -}}
 {{ fail "No storage mode is configured. Review configuration for cocov.storage"}}
{{- end -}}
{{- if .Values.cache.enabled }}
{{ include "envVar" (list "COCOV_REPOSITORY_CACHE_MAX_SIZE" (include "sizeInBytes" .Values.cache.repositoryMaxSize)) }}
{{ include "envVar" (list "COCOV_CACHE_SERVICE_URL" (include "clusterLocalHost" (list "cache" .))) }}
{{- end }}
{{- if and .Values.badger.enabled .Values.api.badger .Values.api.badger.baseURL }}
{{ include "envVar" (list "COCOV_BADGES_BASE_URL" .Values.api.badger.baseURL) }}
{{- end }}
{{- end }}
