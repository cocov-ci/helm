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

{{ define "apiEnvs" -}}
- name: COCOV_GITHUB_ORG_NAME
  value: {{ .Values.api.github.orgName | quote }}
- name: COCOV_GITHUB_APP_ID
  value: {{ .Values.api.github.app.id | quote }}
- name: COCOV_GITHUB_APP_PRIVATE_KEY
  value: {{ .Values.api.github.app.privateKey | quote }}
- name: COCOV_GITHUB_APP_INSTALLATION_ID
  value: {{ .Values.api.github.app.installationID | quote }}
- name: COCOV_GITHUB_WEBHOOK_SECRET_KEY
  value: {{ .Values.api.github.app.webhookSecret | quote }}
- name: COCOV_GITHUB_OAUTH_CLIENT_ID
  value: {{ .Values.api.github.app.clientID | quote }}
- name: COCOV_GITHUB_OAUTH_CLIENT_SECRET
  value: {{ .Values.api.github.app.clientSecret | quote }}
- name: COCOV_DATABASE_USERNAME
  value: {{ .Values.api.db.username | quote }}
- name: COCOV_DATABASE_PASSWORD
  value: {{ .Values.api.db.password | quote }}
- name: COCOV_DATABASE_NAME
  value: {{ .Values.api.db.name | quote }}
- name: COCOV_DATABASE_HOST
  value: {{ .Values.api.db.host | quote }}
- name: COCOV_DATABASE_PORT
  value: {{ .Values.api.db.port | quote }}
- name: SECRET_KEY_BASE
  value: {{ .Values.api.secretKeyBase | quote }}
- name: COCOV_CRYPTOGRAPHIC_KEY
  value: {{ .Values.api.cryptoKey | quote }}
- name: COCOV_UI_BASE_URL
  value: {{ .Values.ui.externalURL | quote }}
- name: COCOV_ALLOW_OUTSIDE_COLLABORATORS
  value: {{ .Values.api.github.allowOutsideCollaborators | quote}}
- name: COCOV_REDIS_URL
  value: {{ .Values.redis.commonURL | quote }}
- name: COCOV_REDIS_CACHE_URL
  value: {{ .Values.redis.cacheURL | quote }}
- name: COCOV_SIDEKIQ_REDIS_URL
  value: {{ .Values.redis.sidekiqURL | quote }}
{{ if and .Values.storage.local.enabled .Values.storage.s3.enabled -}}
{{ fail "Only a single storage mode must be enabled at a single time. Review configuration for cocov.storage."}}
{{- end -}}
{{- if .Values.storage.s3.enabled -}}
- name: COCOV_GIT_SERVICE_STORAGE_MODE
  value: "s3"
- name: COCOV_GIT_SERVICE_S3_STORAGE_BUCKET_NAME
  value: {{ .Values.storage.s3.bucketName | quote }}
{{- else if .Values.storage.local.enabled -}}
- name: COCOV_GIT_SERVICE_STORAGE_MODE
  value: "local"
- name: COCOV_GIT_SERVICE_LOCAL_STORAGE_PATH
  value: {{ .Values.storage.local.mountPath | quote }}
{{- else -}}
 {{ fail "No storage mode is configured. Review configuration for cocov.storage"}}
{{- end -}}
{{- if .Values.cache.enabled }}
- name: COCOV_REPOSITORY_CACHE_MAX_SIZE
  value: {{ (include "sizeInBytes" .Values.cache.repositoryMaxSize) | quote }}
- name: COCOV_CACHE_SERVICE_URL
  value: {{ include "clusterLocalHost" (list "cache" .) }}
{{- end }}
{{- end }}
