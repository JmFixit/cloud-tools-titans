{{- $titanSideCars := .titanSideCars }}
{{- if $titanSideCars }}
  {{- $integration := $titanSideCars.integration }}
  {{- if $integration }}
    {{- $environment := $integration.environment }}
    {{- $tests := $integration.tests }}
    {{- if $tests }}

#!/bin/bash
echo ""
echo "### Execute manual configured integration tests ###"


{{ template "test_cases_core_framework" (dict "environment" $environment "tests" $tests) }}

    {{- end }}
  {{- end }}
{{- end }}
