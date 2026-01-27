{{- define "app.pvcs" -}}
{{- $root := . }}

persistence:

{{- range tuple "arkA" "arkB" }}
  {{ . }}:
    enabled: {{ $root.Values.arkClusterHelm.serverStorage.enabled }}
    type: persistentVolumeClaim
    suffix: pvc
    storageClass: {{ $root.Values.arkClusterHelm.serverStorage.storageClass }}
    accessMode: {{ $root.Values.arkClusterHelm.serverStorage.accessMode }}
    size: {{ $root.Values.arkClusterHelm.serverStorage.size }}
    retain: {{ $root.Values.arkClusterHelm.serverStorage.retain }}

{{- end }}

  cluster:
    enabled: {{ .Values.arkClusterHelm.clusterStorage.enabled }}
    type: persistentVolumeClaim
    suffix: pvc
    storageClass: {{ .Values.arkClusterHelm.clusterStorage.storageClass }}
    accessMode: {{ .Values.arkClusterHelm.clusterStorage.accessMode }}
    size: {{ .Values.arkClusterHelm.clusterStorage.size }}
    retain: {{ .Values.arkClusterHelm.clusterStorage.retain }}

{{- end }}