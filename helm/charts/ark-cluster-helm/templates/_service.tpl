{{- define "app.svc" -}}
{{- $root := . }}

service:
  {{- $gamePort := .Values.arkClusterHelm.servers.gamePortStart }}
  {{- $rconPort := .Values.arkClusterHelm.servers.rconPortStart }}
  {{- $mapStart := 1 }}
  {{- range .Values.arkClusterHelm.servers.maps  }}
  "ark{{ $mapStart }}":
    enabled: true
    controller: "ark{{ $mapStart }}"
    primary: true
    type: LoadBalancer
    forceRename: "ark{{ $mapStart }}-svc"

    annotations: {}
    labels: {}

    ports:
      tcp1:
        enabled: true
        primary: false
        port: {{ $gamePort }}
        protocol: TCP
        targetPort: 7777
      tcp2:
        enabled: true
        primary: false
        port: {{ add $gamePort 1 }}
        protocol: TCP
        targetPort: 7778
      udp:
        enabled: true
        primary: true
        port: {{ $rconPort }}
        protocol: UDP
        targetPort: 27010

  {{- $gamePort = add $gamePort 2 }}
  {{- $rconPort = add $rconPort 1 }}
  {{- $mapStart = add $mapStart 1 }}


  {{- end }}
{{- end }}