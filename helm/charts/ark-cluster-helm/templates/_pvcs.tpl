
{{- define "app.pvcs" -}}

persistence:
  {{- range tuple "arkA" "arkB" "cluster"  }}
  
  {{ . }}:
    enabled: {{ .Values.arkClusterHelm.storage.enabled }}
    type: persistentVolumeClaim
    storageClass: {{ .Values.arkClusterHelm.storage.storageClass }}
    accessMode: {{ .Values.arkClusterHelm.storage.accessMode }}
    size: {{ .Values.arkClusterHelm.storage.size }}
    retain: {{ .Values.arkClusterHelm.storage.retain }}

  {{- end }}
{{- end }}