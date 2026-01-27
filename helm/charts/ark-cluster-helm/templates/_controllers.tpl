{{- define "app.controllers" -}}
{{- $root := . }}

controllers:
  
  init_job:
    enabled: true
    type: job
    annotations: {}
    labels: {}

    job:
      ttlSecondsAfterFinished: 1800
      backoffLimit: 3
      completions: 1

    containers:
      initJob:
        nameOverride: "ark_init_job"

        image:
          repository: {{ .Values.arkClusterHelm.servers.imageRepo }}
          tag: {{ .Values.arkClusterHelm.servers.imageTag }}
          pullPolicy: IfNotPresent

        args: ["init"]

        volumeMounts:
          - name: configVolume
            mountPath: /mnt/configmap
            readOnly: true

        env: []
        envFrom:
          - configMapRef:
              name: ark-global-settings
          - configMapRef:
              name: ark-cluster-state
          - secretRef:
              name: ark-cluster-secrets

        {{- include "ark.helpers.probes" . | nindent 8 }}

        {{- include "ark.helpers.securityContextUser" . | nindent 8 }}
        

    volumes:
      - name: configVolume
        configMap:
          name: ark-global-configfiles

  update_job:
    enabled: true
    type: cronjob
    annotations: {}
    labels: {}
    replicas: 1
    revisionHistoryLimit: 3

    cronjob:
      suspend: false
      concurrencyPolicy: Forbid
      timeZone: {{ .Values.global.timezone }}
      schedule: "0 5 * * *"
      startingDeadlineSeconds: 30
      successfulJobsHistory: 3
      failedJobsHistory: 3
      backoffLimit: 3


    containers:
      initJob:
        nameOverride: "ark_update_job"

        image:
          repository: {{ .Values.arkClusterHelm.servers.imageRepo }}
          tag: {{ .Values.arkClusterHelm.servers.imageTag }}
          pullPolicy: IfNotPresent

        args: ["update"]

        volumeMounts:
          - name: configVolume
            mountPath: /mnt/configmap
            readOnly: true

        env: []
        envFrom:
          - configMapRef:
              name: ark-global-settings
          - configMapRef:
              name: ark-cluster-state
          - secretRef:
              name: ark-cluster-secrets

        {{- include "ark.helpers.probes" . | nindent 8 }}
        {{- include "ark.helpers.securityContextUser" . | nindent 8 }}

    volumes:
      - name: configVolume
        configMap:
          name: ark-global-configfiles


  ## Looping Louis
  {{- $mapStart := 1 }}
  {{- range .Values.arkClusterHelm.servers.maps  }}
  ark{{ $mapStart }}:
    enabled: true
    type: statefulset
    annotations: {}
    labels: {}
    replicas: 1
    strategy: OnDelete

    revisionHistoryLimit: 3

    statefulset:
      volumeClaimTemplates: 
      - name: savedData
        labels: {}
        annotations: {}
        globalMounts:
          - path: /mnt/saved
        accessMode: {{ $root.Values.arkClusterHelm.servers.persistence.accessMode }}
        size: {{ $root.Values.arkClusterHelm.servers.persistence.size }}
        storageClass: {{ $root.Values.arkClusterHelm.servers.persistence.storageClass }}

    containers:
      main:
        nameOverride: "ark-{{ $mapStart }}"

        image:
          repository: {{ $root.Values.arkClusterHelm.servers.imageRepo }}
          tag: {{ $root.Values.arkClusterHelm.servers.imageTag }}
          pullPolicy: IfNotPresent

        args: ["server"]
        
        env:
          ARK_SERVER_MAP: {{ . }}

        envFrom:
          - configMapRef:
              name: ark-global-settings
          - configMapRef:
              name: ark-cluster-state
          - secretRef:
              name: ark-cluster-secrets

        resources: {}

        volumeMounts:
          - name: configVolume
            mountPath: /mnt/configmap
            readOnly: true
        
        {{- include "ark.helpers.probes" . | nindent 8 }}
        {{- include "ark.helpers.securityContextUser" . | nindent 8 }}

    volumes:
      - name: configVolume
        configMap:
          name: ark-global-configfiles

    {{- $mapStart = add $mapStart 1 }}
    {{- end }}

{{- end }}