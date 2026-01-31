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
    advancedMounts:
      init_job:
        initJob:
          - path: "/mnt/{{ . }}"
            readonly: false
      update_job:
        updateJob:
          - path: "/mnt/{{ . }}"
            readonly: false
    {{- $currentPVC := . -}}
    {{- $mapStart := 1 }}
    {{- range $root.Values.arkClusterHelm.servers.maps  }}
      ark{{ $mapStart }}:
        main:
          - path: "/mnt/{{ $currentPVC }}"
            readonly: true
    {{- $mapStart = add $mapStart 1 -}}
    {{- end }}

{{- end }}

  cluster:
    enabled: {{ .Values.arkClusterHelm.clusterStorage.enabled }}
    type: persistentVolumeClaim
    suffix: pvc
    storageClass: {{ .Values.arkClusterHelm.clusterStorage.storageClass }}
    accessMode: {{ .Values.arkClusterHelm.clusterStorage.accessMode }}
    size: {{ .Values.arkClusterHelm.clusterStorage.size }}
    retain: {{ .Values.arkClusterHelm.clusterStorage.retain }}
    globalMounts:
      - path: "/mnt/cluster"

  clusterState:
    enabled: true
    type: configMap
    name: "ark-global-configfiles"
    globalMounts:
      - path: "/mnt/configmap"


{{- end }}