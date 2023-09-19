{{- define "test_cases_core_framework" }}
  {{- $environment := .environment -}}
  {{- $tests := .tests -}}
  {{- if and $environment $tests }}
    {{- $ingress := $environment.ingress | default (dict "address" "envoy-ingress:9443") }}
    {{- $logFolder := $environment.logFolder | default "./logs" }}

{{ template "validation_bash_core_functions" }}

mkdir -p {{ $logFolder }}

# setup single trap
trap 'trp' SIGUSR1
trap 'trp' SIGTERM
trp() {
  echo "[`date -Is`] receive signal to exit" >> "{{ $logFolder }}/envoy-ingress-health-check.log"
  exit 0
}

expectedFailedCalls=0
expectedfailedTestChecks=0

testCalls=0
succeedCalls=0
failedCalls=0
testChecks=0
failedTestChecks=0
succeedTestChecks=0
badTestChecks=0
    {{- printf "\n" }}
    {{- range $tests }}
      {{- $name := .name }}
      {{- $request := .request }}
      {{- $result := .result }}
      {{- if $request }}
        {{- $address := $request.address | default $ingress.address }}
        {{- $token := $request.token }}
        {{- $authType := "" }}
        {{- if $token }}
          {{- $privs := $token.privs | default "" }}
          {{- $scope := $token.scope | default "" }}            
          {{- $roles := $token.roles | default "" }}            
          {{- $uri := $token.uri | default "" }}
          {{- $cid := $token.customer_id | default "" }}
          {{- $did := $token.domain_id | default "" }}
          {{- $clid := $token.client_id | default "" }}
          {{- printf "get_token" }}
          {{- $authType = "Bearer" }}
        {{- end }}
        {{- $headers := $request.headers }}
        {{- $hdrStr := "" }}
        {{- range $headers -}}
          {{- if eq  $hdrStr "" -}}
            {{- $hdrStr = printf "-H %s:%s" .name .value -}}
          {{- else -}}
            {{- $hdrStr = printf "%s %s:%s" $hdrStr .name .value -}}
          {{- end -}}
        {{- end -}}
        {{- $method := $request.method | default "GET" }}
        {{- $path := $request.path | default "/" }}
        {{- $url := printf "%s%s" $address $path }}
        {{- $bodyStr := ternary ($request.body | toJson) "" (hasKey $request "body") }}
        {{- printf "http_call %s %s %s %s %s\n" ($method | quote) ($url | quote) ($hdrStr | squote) ($authType | quote) ($bodyStr | squote) }}
        {{- if $result }}
          {{- printf "unset validation_array && declare -A validation_array\n" }}
          {{- if $result.code }}
            {{- $code := $result.code }}
            {{- printf "validation_array[%s]=%s\n" ("code" | quote) (printf "%s:::%s" ($code.op | default "eq") $code.value | quote) }}
          {{- end }}
          {{- $body := $result.body }}
          {{- range $body }}
            {{- if and .path (or .value .op) }}
              {{- printf "validation_array[%s]=%s\n" (.path | quote) (printf "%s:::%s" (.op | default "eq") .value | quote) }}
            {{- end }}
          {{- end }}
          {{- printf "check_and_report\n" }}
          {{- printf "echo %s >> %s\n" (printf "Test case[%s] result[$test_result]: call %s" $name $url | quote) (printf "%s/report.txt" $logFolder | quote) }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- printf "echo %s >> %s\n" ("Summary:" | quote) (printf "%s/report.txt" $logFolder | quote) }}
    {{- printf "echo %s >> %s\n" ("  Completed $testCalls test calls" | quote) (printf "%s/report.txt" $logFolder | quote) }}
    {{- printf "echo %s >> %s\n" ("    Succeed $succeedCalls test calls" | quote) (printf "%s/report.txt" $logFolder | quote) }}
    {{- printf "echo %s >> %s\n" ("    Failed $failedCalls test calls" | quote) (printf "%s/report.txt" $logFolder | quote) }}
    {{- printf "echo %s >> %s\n" ("  Completed $testChecks test checks" | quote) (printf "%s/report.txt" $logFolder | quote) }}
    {{- printf "echo %s >> %s\n" ("    Succeed $succeedCalls test checks" | quote) (printf "%s/report.txt" $logFolder | quote) }}
    {{- printf "echo %s >> %s\n" ("    Failed $failedTestChecks test checks" | quote) (printf "%s/report.txt" $logFolder | quote) }}
    {{- printf "echo %s >> %s\n" ("    $badTestChecks bad tests" | quote) (printf "%s/report.txt" $logFolder | quote) }}
if [ "$failedCalls" == "$expectedFailedCalls" ] && [ "$failedTestChecks" == "$expectedfailedTestChecks" ]
then
  exit 0
else
  exit 1
fi
  {{- end }}
{{- end }}
