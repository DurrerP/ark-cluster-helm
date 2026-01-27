{{- define "app.configsave" -}}
{{- $root := . }}

configMaps:
  arkGlobalSettings:
    enabled: {{ .Values.arkClusterHelm.configMaps.arkGlobalSettings.enabled }}
    labels: {{ default (dict) .Values.arkClusterHelm.configMaps.arkGlobalSettings.labels | toYaml | nindent 6 }}
    annotations: {{ default (dict) .Values.arkClusterHelm.configMaps.arkGlobalSettings.annotations | toYaml | nindent 6 }}
    forceRename: "ark-global-settings"
    data:
      ARK_CLUSTER_ID: {{ .Values.arkClusterHelm.configMaps.arkGlobalSettings.clusterID }}
      ARK_MAX_PLAYERS: {{ .Values.arkClusterHelm.configMaps.arkGlobalSettings.maxPlayers }}
      ARK_MOD_IDS: {{ join "," (default (list) .Values.arkClusterHelm.configMaps.arkGlobalSettings.mods) }}
      ARK_SERVER_OPTS: {{ join "," (default (list) .Values.arkClusterHelm.configMaps.arkGlobalSettings.serverOpts) }}
      ARK_SERVER_PARAMS: {{ join "," (default (list) .Values.arkClusterHelm.configMaps.arkGlobalSettings.serverParams) }}
      ARK_SESSION_NAME_FORMAT: "{{ .Values.arkClusterHelm.configMaps.arkGlobalSettings.sessionName }}"

  arkGlobalConfigfiles:
    enabled: {{ .Values.arkClusterHelm.configMaps.arkGlobalConfigfiles.enabled }}
    labels: 
      {{ default (dict) .Values.arkClusterHelm.configMaps.arkGlobalConfigfiles.labels | toYaml | nindent 6 }}
    annotations:
      {{ default (dict) .Values.arkClusterHelm.configMaps.arkGlobalConfigfiles.annotations | toYaml | nindent 6 }}
    forceRename: "ark-global-configfiles"
    data: {{ .Values.arkClusterHelm.configMaps.arkGlobalConfigfiles.data | toYaml | nindent 6 }}
  arkClusterState:
    enabled: {{ .Values.arkClusterHelm.configMaps.arkClusterState.enabled }}
    labels: {{ default (dict) .Values.arkClusterHelm.configMaps.arkClusterState.labels | toYaml | nindent 6 }}
    annotations: {{ default (dict) .Values.arkClusterHelm.configMaps.arkClusterState.annotations | toYaml | nindent 6 }}
    forceRename: "ark-cluster-state"
    data: {{ .Values.arkClusterHelm.configMaps.arkClusterState.data | toYaml | nindent 6 }}

{{- end }}