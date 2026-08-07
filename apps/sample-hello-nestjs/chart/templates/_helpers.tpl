{{- define "sample-hello-nestjs.fullname" -}}
{{- .Release.Name }}
{{- end -}}

{{- define "sample-hello-nestjs.labels" -}}
app.kubernetes.io/name: sample-hello-nestjs
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
