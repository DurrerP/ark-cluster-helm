{{- define "ark.helpers.probes" -}}
probes:
  liveness:
    enabled: true
    custom: false
    type: TCP
    spec:
      initialDelaySeconds: 0
      periodSeconds: 10
      timeoutSeconds: 1
      failureThreshold: 3
  readiness:
    enabled: true
    custom: false
    type: TCP
    spec:
      initialDelaySeconds: 0
      periodSeconds: 10
      timeoutSeconds: 1
      failureThreshold: 3
  startup:
    enabled: true
    custom: false
    type: TCP
    spec:
      initialDelaySeconds: 0
      timeoutSeconds: 1
      periodSeconds: 5
      failureThreshold: 30

{{- end }}

{{- define "ark.helpers.securityContextUser" -}}
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  runAsNonRoot: true
{{- end }}
{{- define "ark.helpers.securityContextRoot" -}}
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  runAsNonRoot: false
{{- end }}