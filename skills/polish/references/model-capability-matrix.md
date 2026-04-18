# Model Capability Matrix

Use this matrix to choose primary/secondary models per task type.

## Dimensions
- long_context_support
- json_contract_reliability
- style_preservation
- latency_profile
- cost_profile

## Task Mapping

### Create / Rewrite Drafting
- Priority: style_preservation + long_context_support
- Recommended primary: high-context, style-stable model
- Recommended secondary: balanced model with lower cost

### TDK / Layout Validation
- Priority: json_contract_reliability + precision
- Recommended primary: validation-strong model
- Recommended secondary: deterministic low-latency model

### Export Validation / Manifest
- Priority: strict JSON reliability
- Recommended primary: deterministic contract-focused model
- Recommended secondary: same-family lower-cost model

## Scoring Template
Score each candidate from 1 to 5:
- `context_score`
- `json_score`
- `style_score`
- `latency_score`
- `cost_score`

Select by weighted total according to task priorities.
