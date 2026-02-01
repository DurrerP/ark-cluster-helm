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
      udp1:
        enabled: true
        primary: false
        port: {{ $gamePort }}
        protocol: UDP
        targetPort: 7777
      udp2:
        enabled: true
        primary: true
        port: {{ $rconPort }}
        protocol: UDP
        targetPort: 27015

  {{- $gamePort = add $gamePort 2 }}
  {{- $rconPort = add $rconPort 1 }}
  {{- $mapStart = add $mapStart 1 }}


  {{- end }}
{{- end }}