{{- define "app.fullname" -}}
{{- .Release.Name }}
{{- end -}}

{{- define "app.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
