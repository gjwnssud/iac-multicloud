{{- define "hello-nestjs.fullname" -}}
{{- .Release.Name }}
{{- end -}}

{{- define "hello-nestjs.labels" -}}
app.kubernetes.io/name: hello-nestjs
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
