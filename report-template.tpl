{{- if (eq (len .Matches) 0) }}
<h4>No Vulnerabilities found</h4>
{{- else }}
<h4>Vulnerabilities ({{ len .Matches }})</h4>
<table>
    <tr>
        <th>Package</th>
        <th>ID</th>
        <th>Severity</th>
        <th>Installed Version</th>
        <th>Fixed Version</th>
    </tr>
    {{- range .Matches }}
    <tr>
        <td><code>{{ .Artifact.Name }}</code></td>
        <td>{{ .Vulnerability.ID }}</td>
        <td>{{ .Vulnerability.Severity }}</td>
        <td>{{ .Artifact.Version }}</td>
        <td>
        {{- if .Vulnerability.Fix.State }}
        <code>{{ .Vulnerability.Fix.State }}</code>
        {{- end }}
        {{- if (gt (len .Vulnerability.Fix.Versions) 0) }}
        in versions:
        <ul>
        {{- range .Vulnerability.Fix.Versions }}
          <li>{{ . }}</li>
        {{- end }}
        </ul>
        {{- end }}
        </td>
    </tr>
    {{- end }}
</table>
{{- end }}

{{- if (eq (len .IgnoredMatches ) 0) }}
<h4>No Suppressed Vulnerabilities found</h4>
{{- else }}
<h4>Suppressed Vulnerabilities</h4>
<table>
    <tr>
        <th>Package</th>
        <th>ID</th>
        <th>Severity</th>
        <th>Installed Version</th>
        <th>Suppression Status</th>
    </tr>
    {{- range .IgnoredMatches }}
    <tr>
        <td><code>{{ .Artifact.Name }}</code></td>
        <td>{{ .Vulnerability.ID }}</td>
        <td>{{ .Vulnerability.Severity }}</td>
        <td>{{ .Artifact.Version }}</td>
        <td>
        {{- range .AppliedIgnoreRules }}
          <code>${{ .Namespace }}</code>: {{ .Reason }}
        {{- end}}
        </td>
    </tr>
    {{- end }}
</table>
{{- end }}
