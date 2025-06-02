{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "nodeapp.name" -}}
{{- default "nodeapp" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "reactapp.name" -}}
{{- default "reactapp" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "postgres.name" -}}
{{- default "postgres" .Values.database.postgres.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nodeapp.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nodeapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Create PostgreSQL database URL */}}
{{- define "postgres.dburl" -}}
{{- $replicas := (atoi (printf "%d" (int64 .Values.database.postgres.replicas))) -}}
{{- range $i, $e := until $replicas -}}
{{- printf "%s-%d.%s-headless" (include "postgres.name" .) $i (include "postgres.name" .) -}}
{{- if lt (add $i 1) $replicas -}}
,
{{- end -}}
{{- end -}}
{{- end -}}