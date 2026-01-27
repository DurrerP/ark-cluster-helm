{{- define "app.pvcs" -}}
{{- $root := . }}

persistence:
  {{- range tuple "arkA" "arkB" }}
  
  # ark A and ark B
  {{ . }}:
    enabled: {{ $root.Values.arkClusterHelm.serverStorage.enabled }}
    type: persistentVolumeClaim
    suffix: pvc
    storageClass: {{ $root.Values.arkClusterHelm.serverStorage.storageClass }}
    accessMode: {{ $root.Values.arkClusterHelm.serverStorage.accessMode }}
    size: {{ $root.Values.arkClusterHelm.serverStorage.size }}
    retain: {{ $root.Values.arkClusterHelm.serverStorage.retain }}

  {{- end }}

  # cluster shared pvc
  cluster:
    enabled: {{ $root.Values.arkClusterHelm.clusterStorage.enabled }}
      type: persistentVolumeClaim
      suffix: pvc
      storageClass: {{ $root.Values.arkClusterHelm.clusterStorage.storageClass }}
      accessMode: {{ $root.Values.arkClusterHelm.clusterStorage.accessMode }}
      size: {{ $root.Values.arkClusterHelm.clusterStorage.size }}
      retain: {{ $root.Values.arkClusterHelm.clusterStorage.retain }}

{{- end }}