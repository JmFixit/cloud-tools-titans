{{- define "titan-mesh-helm-lib-chart.containers.envoy.containerName" -}}
{{- print "titan-envoy" -}}
{{- end }}

{{- define "titan-mesh-helm-lib-chart.containers.envoy" -}}
{{- $titanSideCars := .titanSideCars -}}
{{- $namespace := .namespace }}
{{- if $titanSideCars }}
  {{- $envoyEnabled := eq (include "static.titan-mesh-helm-lib-chart.envoyEnabled" $titanSideCars) "true" -}}
  {{- $envoy := $titanSideCars.envoy -}}
  {{- $envars := $envoy.env }}
  {{- $clusters := $envoy.clusters }}
  {{- $remoteMyApp := index $clusters "remote-myapp" }}
  {{- $envoyIngressPort := coalesce $remoteMyApp.targetPort $remoteMyApp.port "9443" }}
  {{- $envoyHealthChecks := $remoteMyApp.healthChecks }}
  {{- $envoyHealthChecksStartup := $envoyHealthChecks.startup }}
  {{- $envoyHealthChecksStartupEnabled := ternary $envoyHealthChecksStartup.enabled true  (hasKey $envoyHealthChecksStartup "enabled") }}
  {{- $envoyHealthChecksCmdsStartup := $envoyHealthChecksStartup.commands }}
  {{- $envoyHealthChecksLiveness := $envoyHealthChecks.liveness }}
  {{- $envoyHealthChecksLivenessEnabled := ternary $envoyHealthChecksLiveness.enabled true  (hasKey $envoyHealthChecksLiveness "enabled") }}
  {{- $envoyHealthChecksCmdsLiveness := $envoyHealthChecksLiveness.commands }}
  {{- $envoyHealthChecksReadiness := $envoyHealthChecks.readiness }}
  {{- $envoyHealthChecksReadinessEnabled := ternary $envoyHealthChecksReadiness.enabled true  (hasKey $envoyHealthChecksReadiness "enabled") }}
  {{- $envoyHealthChecksCmdsReadiness := $envoyHealthChecksReadiness.commands }}
  {{- $envoyHealthChecksPath := $envoyHealthChecks.path | default "/healthz" -}}
  {{- $envoyHealthChecksScheme:= $envoyHealthChecks.scheme | default "HTTPS" -}}
  {{- $logs := $titanSideCars.logs -}}
  {{- $logType := $logs.type | default "stream" -}}
  {{- $envoyCPU := $envoy.cpu -}}
  {{- $envoyMemory := $envoy.memory -}}
  {{- $envoyStorage := $envoy.ephemeralStorage -}}
  {{- $imageRegistry := $envoy.imageRegistry | default $titanSideCars.imageRegistry -}}
  {{- $imageRegistry = ternary "" (printf "%s/" $imageRegistry) (eq $imageRegistry "") -}}
  {{- if $envoyEnabled }}
- name: {{include "titan-mesh-helm-lib-chart.containers.envoy.containerName" . }}
  image: {{ printf "%s%s:%s" $imageRegistry  ($envoy.imageName | default "envoy") ($envoy.imageTag | default "latest") }}
  imagePullPolicy: IfNotPresent
  env:
    - name: KUBERNETES_NAMESPACE
      value: {{ $namespace | quote }}
    {{- range $k, $v := $envars }}
    - name: {{ $k | upper }}
      value: {{ $v | quote }}
    {{- end }}  
  command: 
    - /usr/local/bin/envoy 
    - -c
    - /envoy/envoy.yaml
    - --service-cluster
    - {{ .appName }}
    - --service-node
    - ${HOSTNAME}
    - -l
    - {{ $logs.level | default "warning" }}
    {{- if eq $logType "file" }}
    - --log-path
    - "/logs/envoy.application.log"
    {{- else }}
    - --log-format
    - '%L%m%d %T.%e %t envoy] [%t][%n]%v'
    {{- end }}
  resources:
    limits:
      cpu: {{ $envoyCPU.limit | default "1" | quote }}
      memory: {{ $envoyMemory.limit | default "1Gi" | quote }}
      ephemeral-storage: {{ $envoyStorage.limit | default "500Mi" | quote }}
    requests:
      cpu: {{ $envoyCPU.request | default "250m" | quote }}
      memory: {{ $envoyMemory.request | default "256Mi" | quote }}
      ephemeral-storage: {{ $envoyStorage.request | default "100Mi" | quote }}
  lifecycle:
    preStop:
      exec:
        command:
          - sh
          - -c
          - wget --post-data="" -O - http://127.0.0.1:10000/healthcheck/fail && sleep {{ $envoy.connectionDrainDuration | default "80" }} || true
    {{- if $envoyHealthChecksStartupEnabled }}
  startupProbe:
      {{- if $envoyHealthChecksCmdsStartup }}
    exec:
      command:
        {{- range $envoyHealthChecksCmdsStartup }}
       {{ printf "- %s" . }}
        {{- end }}
      {{- else }}
    httpGet:
      path: {{ $envoyHealthChecksPath }}
      port: {{ $envoyIngressPort }}
      scheme: {{ $envoyHealthChecksScheme}}
      {{- end }}
    initialDelaySeconds: {{ $envoy.startupInitialDelaySeconds | default "5" }}
    failureThreshold: {{ $envoy.startupFailureThreshold | default "300" }}
    periodSeconds: {{ $envoy.startupPeriodSeconds | default "1" }}
    {{- end }}
    {{- if $envoyHealthChecksLiveness }}
  livenessProbe:
      {{- if $envoyHealthChecksCmdsLiveness }}
    exec:
      command:
        {{- range $envoyHealthChecksCmdsLiveness }}
       {{ printf "- %s" . }}
        {{- end }}
      {{- else }}
    httpGet:
      path: {{ $envoyHealthChecksPath }}
      port: {{ $envoyIngressPort }}
      scheme: {{ $envoyHealthChecksScheme}}
      {{- end }}
    initialDelaySeconds: {{ $envoy.livenessInitialDelaySeconds | default "1" }}
    failureThreshold: {{ $envoy.livenessFailureThreshold | default "2" }}
    periodSeconds: {{ $envoy.livenessPeriodSeconds | default "3" }}
    {{- end }}
    {{- if $envoyHealthChecksReadinessEnabled }}
  readinessProbe:
      {{- if $envoyHealthChecksCmdsReadiness }}
    exec:
      command:
        {{- range $envoyHealthChecksCmdsReadiness }}
       {{ printf "- %s" . }}
        {{- end }}
      {{- else }}
    httpGet:
      path: {{ $envoyHealthChecksPath }}
      port: {{ $envoyIngressPort }}
      scheme: {{ $envoyHealthChecksScheme}}
      {{- end }}
    initialDelaySeconds: {{ $envoy.readinessInitialDelaySeconds | default "1" }}
    failureThreshold:  {{ $envoy.readinessFailureThreshold | default "1" }}
    periodSeconds: {{ $envoy.readinessPeriodSeconds | default "3" }}
  {{- end }}
  volumeMounts:
    - mountPath: /envoy/envoy.yaml
      name: titan-configs
      subPath: envoy.yaml
    - mountPath: /envoy/envoy-sds.yaml
      name: titan-configs
      subPath: envoy-sds.yaml
    - mountPath: /logs/
      name: {{ include "titan-mesh-helm-lib-chart.volumes.logsVolumeName" $titanSideCars }}
    - mountPath: /secrets
      name: titan-secrets-tls
  {{- end }}
{{- end }}
{{- end }}


