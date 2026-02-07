{{/* Define full name for resources */}}
{{- define "my-flask-chart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Define common labels */}}
{{- define "my-flask-chart.labels" -}}
app.kubernetes.io/name: {{ include "my-flask-chart.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Define a "name" helper for selector labels */}}
{{- define "my-flask-chart.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{/* Define selector labels for deployments */}}
{{- define "my-flask-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-flask-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
