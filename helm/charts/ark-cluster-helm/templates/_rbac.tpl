{{- define "app.rbacs" -}}

rbac:
  roles:
    role1:
      enabled: true
      type: Role
      rules:
        - apiGroups: [""]
          resources: ["configmaps"]
          verbs: ["get", "patch"]
        - apiGroups: ["apps"]
          resources: ["statefulsets"]
          verbs: ["get", "list", "watch", "patch"]
        - apiGroups: [""]
          resources: ["pods"]
          verbs: ["get", "list", "watch"]

  bindings:
    role2:
      enabled: true
      type: RoleBinding
      roleRef:
        identifier: role1
      subjects:
        - kind: ServiceAccount
          name: "ark-sa"
          namespace: "{{ .Release.Namespace }}"

{{- end }}