{{/*
Labels communs appliqués à toutes les ressources du chart.
Appelé via : {{- include "ecommerce.labels" $ | nindent 4 }}
*/}}
{{- define "ecommerce.labels" -}}
app.kubernetes.io/part-of: ecommerce
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
