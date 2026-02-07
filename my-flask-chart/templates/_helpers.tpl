{{/* Define full name for resources */}}
{{- define "my-flask-chart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Define common labels */}}
{{- define "my-flask-chart.labels" -}}
app.kubernetes.io/name: {{ include "my-flask-chart.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Define selector labels */}}
{{- define "my-flask-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-flask-chart.fullname" . }}
{{- end -}}

{{/* Define the ServiceAccount name */}}
{{- define "my-flask-chart.serviceAccountName" -}}
{{- default (include "my-flask-chart.fullname" .) .Values.serviceAccount.name -}}
{{- end -}}
