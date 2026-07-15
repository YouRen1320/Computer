#!/usr/bin/env ruby
# frozen_string_literal: true

# Read-only structural validator for FactoryCare's design baseline.
# It checks parseability and naming invariants; it does not prove runtime behavior.

require "csv"
require "json"
require "pathname"
require "set"
require "yaml"

DESIGN_ROOT = Pathname.new(__dir__).parent.expand_path
PROJECT_ROOT = DESIGN_ROOT.parent

MODULES = %w[
  identity organization asset workorder knowledge engagement reporting audit ai-integration
].freeze

NON_BUSINESS_OWNERS = %w[ai shared-infrastructure].freeze

HTTP_METHODS = %w[get post put patch delete].freeze

PUBLIC_REQUIRED_OPERATIONS = %w[
  getCsrfToken
  listOrganizations createOrganization updateOrganization
  listMemberships inviteMembership updateMembership assignMembershipRole revokeMembershipRole
  listRoles
  listTeams createTeam getTeam updateTeam
  listEquipmentModels createEquipmentModel getEquipmentModel updateEquipmentModel
  listLocations createLocation getLocation updateLocation
  listAssets createAsset getAsset updateAsset rotateAssetPublicCode resolveAssetPublicCode
  createReport addReportSupplement verifyOrRejectResolution createReportFeedback
  triageWorkOrder assignWorkOrder reassignWorkOrder acceptWorkOrder startWorkOrder waitForParts
  requestWorkOrderApproval decideWorkOrderApproval resumeWorkOrder resolveWorkOrder
  closeWorkOrder cancelWorkOrder reopenWorkOrder
  createWorkOrderLog recordCheckItemResult recordPartUsage
  createAttachmentUploadIntent completeAttachmentUpload createAttachmentDownloadIntent
  createKnowledgeDocument createKnowledgeUploadIntent bindUploadedKnowledgeVersion
  submitKnowledgeVersionForReview decideKnowledgeVersionReview
  publishKnowledgeVersion revokeKnowledgeVersion
  requestWorkOrderTriageSuggestion streamWorkOrderDiagnosticAnswer
  startPublicEvaluationRun getPublicEvaluationRun
  listAuditLogs startAuditExport getAuditExport
  getOperationsSummary
].freeze

INTERNAL_REQUIRED_OPERATIONS = {
  "suggestWorkOrderTriage" => ["https://factorycare-ai.internal.test", "factorycare-ai"],
  "streamGroundedAnswer" => ["https://factorycare-ai.internal.test", "factorycare-ai"],
  "createResolutionReportDraft" => ["https://factorycare-ai.internal.test", "factorycare-ai"],
  "startEvaluationRun" => ["https://factorycare-ai.internal.test", "factorycare-ai"],
  "getEvaluationRun" => ["https://factorycare-ai.internal.test", "factorycare-ai"],
  "invokeAssetSummaryTool" => ["https://factorycare-java.internal.test", "factorycare-java"],
  "invokeWorkOrderHistoryTool" => ["https://factorycare-java.internal.test", "factorycare-java"]
}.freeze

STREAM_EVENT_SCHEMAS = {
  "PublicAnswerStreamEvent" => %w[
    PublicAnswerStartEvent PublicAnswerTextEvent PublicAnswerCitationEvent
    PublicAnswerNoAnswerEvent PublicAnswerErrorEvent PublicAnswerEndEvent
  ],
  "AnswerStreamEvent" => %w[
    AnswerStartEvent AnswerTextEvent AnswerCitationEvent
    AnswerNoAnswerEvent AnswerErrorEvent AnswerEndEvent
  ]
}.freeze

STATUSES = %w[
  CREATED TRIAGED ASSIGNED ACCEPTED IN_PROGRESS PENDING_PARTS PENDING_APPROVAL
  RESOLVED VERIFIED CLOSED REOPENED CANCELLED
].freeze

EVENT_FILES = {
  "work-order-created.v1.schema.json" => "WorkOrderCreated.v1",
  "work-order-assigned.v1.schema.json" => "WorkOrderAssigned.v1",
  "work-order-resolved.v1.schema.json" => "WorkOrderResolved.v1",
  "work-order-closed.v1.schema.json" => "WorkOrderClosed.v1",
  "knowledge-document-published.v1.schema.json" => "KnowledgeDocumentPublished.v1",
  "knowledge-document-revoked.v1.schema.json" => "KnowledgeDocumentRevoked.v1"
}.freeze

EVENT_ACTOR_FIELDS = {
  "WorkOrderCreated.v1" => "reporterMembershipId",
  "WorkOrderAssigned.v1" => "assignedByMembershipId",
  "WorkOrderResolved.v1" => "technicianMembershipId",
  "WorkOrderClosed.v1" => "closedByMembershipId",
  "KnowledgeDocumentPublished.v1" => "publishedByMembershipId",
  "KnowledgeDocumentRevoked.v1" => "revokedByMembershipId"
}.freeze

ROLE_COLUMNS = %w[
  tenant_admin asset_admin dispatcher knowledge_admin technician reporter supervisor_auditor
].freeze

errors = []
warnings = []
checks = 0
openapi_documents = {}

check = lambda do |condition, message|
  checks += 1
  errors << message unless condition
end

read = lambda do |relative|
  path = DESIGN_ROOT.join(relative)
  check.call(path.file?, "missing file: #{path.relative_path_from(PROJECT_ROOT)}")
  path.file? ? path.read(encoding: "UTF-8") : ""
end

resolve_pointer = lambda do |document, reference|
  next nil unless reference.start_with?("#/")

  reference.delete_prefix("#/").split("/").reduce(document) do |node, token|
    break nil unless node.is_a?(Hash)

    node[token.gsub("~1", "/").gsub("~0", "~")]
  end
end

walk = lambda do |node, &block|
  block.call(node)
  case node
  when Hash
    node.each_value { |value| walk.call(value, &block) }
  when Array
    node.each { |value| walk.call(value, &block) }
  end
end

puts "FactoryCare design validation"
puts "root: #{DESIGN_ROOT}"

# Parse and inspect both OpenAPI documents.
{
  "contracts/public-api.yaml" => "/api/v1",
  "contracts/ai-internal-api.yaml" => "/internal/v1"
}.each do |relative, prefix|
  source = read.call(relative)
  begin
    document = YAML.safe_load(source, aliases: false)
    check.call(document.is_a?(Hash), "#{relative}: root must be a mapping")
    next unless document.is_a?(Hash)
    openapi_documents[relative] = document

    check.call(document["openapi"].to_s.start_with?("3.1."), "#{relative}: expected OpenAPI 3.1.x")
    paths = document["paths"]
    check.call(paths.is_a?(Hash) && !paths.empty?, "#{relative}: paths must not be empty")
    if paths.is_a?(Hash)
      invalid_paths = paths.keys.reject { |path| path.start_with?(prefix) }
      check.call(invalid_paths.empty?, "#{relative}: paths outside #{prefix}: #{invalid_paths.join(', ')}")
    end

    operation_ids = []
    walk.call(document) do |node|
      next unless node.is_a?(Hash)

      operation_ids << node["operationId"] if node["operationId"]
      reference = node["$ref"]
      if reference&.start_with?("#/")
        check.call(!resolve_pointer.call(document, reference).nil?, "#{relative}: unresolved ref #{reference}")
      elsif reference
        warnings << "#{relative}: external ref not checked: #{reference}"
      end
    end
    duplicate_operations = operation_ids.group_by(&:itself).select { |_id, values| values.length > 1 }.keys
    check.call(duplicate_operations.empty?, "#{relative}: duplicate operationId: #{duplicate_operations.join(', ')}")
  rescue Psych::Exception => e
    errors << "#{relative}: YAML parse error: #{e.message.lines.first.strip}"
  end
end

# Semantic OpenAPI checks that parseability and reference resolution cannot prove.
operation_map = lambda do |document|
  operations = {}
  document.fetch("paths", {}).each do |path, path_item|
    next unless path_item.is_a?(Hash)

    HTTP_METHODS.each do |method|
      operation = path_item[method]
      next unless operation.is_a?(Hash)

      operation_id = operation["operationId"]
      operations[operation_id] = {
        "path" => path,
        "method" => method,
        "path_item" => path_item,
        "operation" => operation
      } if operation_id
    end
  end
  operations
end

check_closed_all_of = lambda do |relative, document|
  schemas = document.dig("components", "schemas")
  next unless schemas.is_a?(Hash)

  schemas.each do |schema_name, schema|
    next unless schema.is_a?(Hash) && schema["allOf"].is_a?(Array)

    extension_properties = schema["allOf"].map do |branch|
      branch.is_a?(Hash) && branch["properties"].is_a?(Hash) ? branch["properties"].keys : []
    end.flatten
    next if extension_properties.empty?

    schema["allOf"].each do |branch|
      next unless branch.is_a?(Hash) && branch["$ref"].to_s.start_with?("#/")

      base = resolve_pointer.call(document, branch["$ref"])
      next unless base.is_a?(Hash) && base["additionalProperties"] == false

      base_properties = base.fetch("properties", {}).keys
      blocked = extension_properties - base_properties
      check.call(blocked.empty?,
                 "#{relative}: #{schema_name} extends closed #{branch['$ref']} with blocked fields #{blocked.join(', ')}")
    end
  end
end

openapi_documents.each do |relative, document|
  check_closed_all_of.call(relative, document)
end

public_relative = "contracts/public-api.yaml"
public_api = openapi_documents[public_relative]
if public_api
  public_operations = operation_map.call(public_api)
  missing_operations = PUBLIC_REQUIRED_OPERATIONS - public_operations.keys
  check.call(missing_operations.empty?,
             "#{public_relative}: missing required operations: #{missing_operations.join(', ')}")

  statuses = public_api.dig("components", "schemas", "WorkOrderStatus", "enum")
  check.call(statuses == STATUSES, "#{public_relative}: WorkOrderStatus must contain the exact 12-state set")

  schemas = public_api.dig("components", "schemas") || {}
  required_routes = {
    "listTeams" => ["get", "/api/v1/teams"],
    "createTeam" => ["post", "/api/v1/teams"],
    "getTeam" => ["get", "/api/v1/teams/{teamId}"],
    "updateTeam" => ["patch", "/api/v1/teams/{teamId}"],
    "listRoles" => ["get", "/api/v1/roles"],
    "listEquipmentModels" => ["get", "/api/v1/equipment-models"],
    "createEquipmentModel" => ["post", "/api/v1/equipment-models"],
    "getEquipmentModel" => ["get", "/api/v1/equipment-models/{equipmentModelId}"],
    "updateEquipmentModel" => ["patch", "/api/v1/equipment-models/{equipmentModelId}"],
    "listLocations" => ["get", "/api/v1/locations"],
    "createLocation" => ["post", "/api/v1/locations"],
    "getLocation" => ["get", "/api/v1/locations/{locationId}"],
    "updateLocation" => ["patch", "/api/v1/locations/{locationId}"],
    "reassignWorkOrder" => ["post", "/api/v1/work-orders/{workOrderId}/reassignments"]
  }
  required_routes.each do |operation_id, expected|
    entry = public_operations[operation_id]
    check.call(entry && [entry["method"], entry["path"]] == expected,
               "#{public_relative}: #{operation_id} must be #{expected[0].upcase} #{expected[1]}")
  end

  team_required = Array(schemas.dig("Team", "required"))
  check.call((%w[id organizationId name status version] - team_required).empty?,
             "#{public_relative}: Team schema lacks its minimum entity fields")

  team_scope_constraint = lambda do |schema|
    Array(schema && schema["allOf"]).any? do |rule|
      next false unless rule.is_a?(Hash)

      team_if = rule.dig("if", "properties", "dataScope", "const") == "TEAM"
      then_requires = Array(rule.dig("then", "required")).include?("teamId")
      then_string = rule.dig("then", "properties", "teamId", "type") == "string"
      team_if && (then_requires || then_string)
    end
  end
  %w[MembershipSummary InviteMembershipRequest UpdateMembershipRequest].each do |schema_name|
    schema = schemas[schema_name]
    team_id_type = Array(schema&.dig("properties", "teamId", "type"))
    check.call(team_id_type.include?("string") && team_id_type.include?("null"),
               "#{public_relative}: #{schema_name}.teamId must be nullable UUID text")
    check.call(team_scope_constraint.call(schema),
               "#{public_relative}: #{schema_name} must require non-null teamId for TEAM dataScope")
  end

  attachment_purposes = schemas.dig("AttachmentPurpose", "enum")
  check.call(attachment_purposes == %w[REPORT_CREATION REPORT_SUPPLEMENT WORK_ORDER],
             "#{public_relative}: AttachmentPurpose must contain only report/work-order upload purposes")
  check.call(!schemas.key?("AttachmentOwnerType"),
             "#{public_relative}: obsolete AttachmentOwnerType must be removed")
  check.call(!JSON.generate(public_api).include?("KNOWLEDGE_DOCUMENT"),
             "#{public_relative}: generic attachments must not claim knowledge-document ownership")
  attachment_request = schemas["CreateAttachmentUploadIntentRequest"] || {}
  check.call(Array(attachment_request["required"]).include?("purpose") &&
             attachment_request.dig("properties", "purpose", "$ref") == "#/components/schemas/AttachmentPurpose" &&
             !attachment_request.fetch("properties", {}).key?("ownerType"),
             "#{public_relative}: attachment upload request must use purpose, not ownerType")
  check.call(Array(schemas.dig("AttachmentBusinessOwnerType", "enum")) == %w[REPORT WORK_ORDER],
             "#{public_relative}: final attachment business owner must be REPORT or WORK_ORDER")

  approval_decisions = schemas.dig("DecideWorkOrderApprovalRequest", "properties", "decision", "enum")
  check.call(approval_decisions == %w[APPROVE REQUEST_CHANGES],
             "#{public_relative}: work-order approval decision must be APPROVE or REQUEST_CHANGES")

  assign_required = Array(schemas.dig("AssignWorkOrderRequest", "required"))
  check.call((%w[teamId technicianMembershipId version] - assign_required).empty?,
             "#{public_relative}: initial assignment must require team, technician, and version")
  reassign_required = Array(schemas.dig("ReassignWorkOrderRequest", "required"))
  check.call((%w[teamId technicianMembershipId reason version] - reassign_required).empty?,
             "#{public_relative}: reassignment must require team, technician, reason, and version")
  detail_extension = Array(schemas.dig("WorkOrderDetail", "allOf")).find do |branch|
    branch.is_a?(Hash) && branch.dig("properties", "assignedTeamId")
  end
  check.call(!detail_extension.nil?, "#{public_relative}: WorkOrderDetail must expose assignedTeamId")

  qr_path = public_api.dig("paths", "/api/v1/asset-codes:resolve", "post")
  check.call(qr_path.is_a?(Hash), "#{public_relative}: missing body-based asset-code resolver")
  if qr_path.is_a?(Hash)
    check.call(qr_path["security"] == [], "#{public_relative}: asset-code resolver must be anonymous")
    check.call(qr_path.dig("requestBody", "content", "application/json", "schema", "$ref") ==
               "#/components/schemas/ResolveAssetCodeRequest",
               "#{public_relative}: asset-code resolver must use ResolveAssetCodeRequest body")
    check.call(qr_path.fetch("responses", {}).key?("400"),
               "#{public_relative}: asset-code resolver must contract malformed input as 400")
    check.call(qr_path.fetch("responses", {}).key?("429"),
               "#{public_relative}: asset-code resolver must contract 429")
    check.call(qr_path.dig("responses", "200", "content", "application/json", "schema", "$ref") ==
               "#/components/schemas/AnonymousResolvableAsset",
               "#{public_relative}: asset-code resolver 200 must use the anonymous minimal schema")
  end
  anonymous_asset = schemas["AnonymousResolvableAsset"] || {}
  check.call(Array(anonymous_asset["required"]) == %w[assetId displayName] &&
             !anonymous_asset.fetch("properties", {}).key?("status"),
             "#{public_relative}: anonymous asset response must expose only assetId and displayName")
  check.call(!public_api.fetch("paths", {}).keys.any? { |path| path.include?("{publicCode}") },
             "#{public_relative}: high-entropy publicCode must not appear in a URL path")

  global_security = Array(public_api["security"])
  browser_csrf = global_security.any? do |requirement|
    requirement.is_a?(Hash) && requirement.keys.to_set == Set["browserSession", "csrfHeader"]
  end
  bearer = global_security.any? do |requirement|
    requirement.is_a?(Hash) && requirement.keys == ["mobileBearer"]
  end
  check.call(browser_csrf && bearer,
             "#{public_relative}: global security must be browserSession+csrfHeader OR mobileBearer")

  public_operations.each do |operation_id, entry|
    next unless entry["method"] == "get"
    next if operation_id == "getCsrfToken"

    safe_security = Array(entry["operation"]["security"])
    browser_safe = safe_security.any? do |requirement|
      requirement.is_a?(Hash) && requirement.keys == ["browserSession"]
    end
    bearer_safe = safe_security.any? do |requirement|
      requirement.is_a?(Hash) && requirement.keys == ["mobileBearer"]
    end
    check.call(browser_safe && bearer_safe,
               "#{public_relative}: safe GET #{operation_id} must not require a CSRF header")
  end

  get_forbidden_exceptions = %w[getCurrentActor getCsrfToken].to_set
  public_operations.each do |operation_id, entry|
    next unless entry["method"] == "get"
    next if entry["operation"]["security"] == []

    responses = entry["operation"].fetch("responses", {})
    check.call(responses.key?("401"), "#{public_relative}: protected GET #{operation_id} missing 401 response")
    unless get_forbidden_exceptions.include?(operation_id)
      check.call(responses.key?("403"), "#{public_relative}: protected GET #{operation_id} missing 403 response")
    end
    if entry["path"].include?("{")
      check.call(responses.key?("404"), "#{public_relative}: resource GET #{operation_id} missing 404 response")
    end
  end

  logout_responses = public_operations.dig("logoutCurrentSession", "operation", "responses") || {}
  check.call(logout_responses.key?("403"), "#{public_relative}: logout must contract CSRF/authorization failure as 403")

  mutation_exceptions = %w[loginWithSession logoutCurrentSession resolveAssetPublicCode].to_set
  public_operations.each do |operation_id, entry|
    next unless %w[post put patch delete].include?(entry["method"])
    next if mutation_exceptions.include?(operation_id)

    parameters = Array(entry["path_item"]["parameters"]) + Array(entry["operation"]["parameters"])
    has_idempotency = parameters.any? do |parameter|
      parameter.is_a?(Hash) && parameter["$ref"] == "#/components/parameters/IdempotencyKey"
    end
    check.call(has_idempotency, "#{public_relative}: #{operation_id} must require Idempotency-Key")

    responses = entry["operation"].fetch("responses", {})
    %w[400 401 403 409].each do |status|
      check.call(responses.key?(status), "#{public_relative}: #{operation_id} missing #{status} response")
    end
    if entry["path"].include?("{")
      check.call(responses.key?("404"), "#{public_relative}: #{operation_id} missing 404 response")
    end
  end

  public_stream = public_api.dig("components", "schemas", "PublicAnswerStreamEvent", "oneOf")
  public_stream_refs = Array(public_stream).map { |branch| branch["$ref"]&.split("/")&.last }.compact
  check.call(public_stream_refs == STREAM_EVENT_SCHEMAS["PublicAnswerStreamEvent"],
             "#{public_relative}: public NDJSON stream event union differs")

  operations_summary = public_api.dig("components", "schemas", "OperationsSummary", "required")
  required_metrics = %w[
    firstTimeResolutionRate repeatFailureRate knowledgeHitRate aiSuggestionAdoptionRate
  ]
  check.call((required_metrics - Array(operations_summary)).empty?,
             "#{public_relative}: OperationsSummary missing required business metrics")

  triage_required = public_api.dig("components", "schemas", "TriageWorkOrderRequest", "required")
  check.call(Array(triage_required).include?("suggestionDisposition"),
             "#{public_relative}: triage confirmation must record AI suggestion disposition")
end

internal_relative = "contracts/ai-internal-api.yaml"
internal_api = openapi_documents[internal_relative]
if internal_api
  internal_operations = operation_map.call(internal_api)
  INTERNAL_REQUIRED_OPERATIONS.each do |operation_id, routing|
    expected_url, expected_audience = routing
    entry = internal_operations[operation_id]
    check.call(!entry.nil?, "#{internal_relative}: missing required operation #{operation_id}")
    next unless entry

    urls = Array(entry["operation"]["servers"]).map { |server| server["url"] }
    check.call(urls == [expected_url],
               "#{internal_relative}: #{operation_id} must route only to #{expected_url}")
    check.call(entry["operation"]["x-service-audience"] == expected_audience,
               "#{internal_relative}: #{operation_id} audience must be #{expected_audience}")
  end

  internal_operations.each do |operation_id, entry|
    responses = entry["operation"].fetch("responses", {})
    %w[400 401 403 429 503].each do |status|
      check.call(responses.key?(status),
                 "#{internal_relative}: internal operation #{operation_id} missing #{status} response")
    end
  end

  internal_stream = internal_api.dig("components", "schemas", "AnswerStreamEvent", "oneOf")
  internal_stream_refs = Array(internal_stream).map { |branch| branch["$ref"]&.split("/")&.last }.compact
  check.call(internal_stream_refs == STREAM_EVENT_SCHEMAS["AnswerStreamEvent"],
             "#{internal_relative}: internal NDJSON stream event union differs")
end

# JSON Schema event directory must be exact and internally self-identifying.
event_directory = DESIGN_ROOT.join("events")
actual_event_files = event_directory.glob("*.schema.json").map(&:basename).map(&:to_s).sort
check.call(actual_event_files == EVENT_FILES.keys.sort,
           "event schema set differs; expected #{EVENT_FILES.keys.sort}, got #{actual_event_files}")

EVENT_FILES.each do |file_name, event_name|
  source = read.call("events/#{file_name}")
  begin
    schema = JSON.parse(source)
    check.call(schema["$schema"].to_s.include?("2020-12"), "#{file_name}: expected JSON Schema 2020-12")
    check.call(schema["title"] == event_name, "#{file_name}: title must be #{event_name}")
    check.call(schema.dig("properties", "eventType", "const") == event_name,
               "#{file_name}: eventType const must be #{event_name}")
    check.call(schema.dig("properties", "version", "const") == 1,
               "#{file_name}: version const must be 1")
    check.call(!schema.fetch("properties", {}).key?("type"),
               "#{file_name}: event envelope must use eventType, not type")
    required = Array(schema["required"])
    envelope = %w[eventId eventType version occurredAt tenantId aggregateId traceId payload]
    check.call((envelope - required).empty?, "#{file_name}: missing envelope required fields: #{(envelope - required).join(', ')}")
    check.call(schema["additionalProperties"] == true,
               "#{file_name}: root must allow unknown optional fields for v1 compatibility")
    check.call(schema.dig("properties", "payload", "additionalProperties") == true,
               "#{file_name}: payload must allow unknown optional fields for v1 compatibility")
    payload_required = Array(schema.dig("properties", "payload", "required"))
    actor_field = EVENT_ACTOR_FIELDS[event_name]
    check.call(payload_required.include?(actor_field),
               "#{file_name}: payload must require actor field #{actor_field}")
    if event_name == "WorkOrderAssigned.v1"
      check.call(payload_required.include?("teamId"),
                 "#{file_name}: assignment event must require teamId")
      check.call(schema.dig("properties", "payload", "properties", "replacesAssignmentId", "type") ==
                 ["string", "null"],
                 "#{file_name}: assignment event must distinguish replacement without a new status")
    end
  rescue JSON::ParserError => e
    errors << "events/#{file_name}: JSON parse error: #{e.message}"
  end
end

# CSV shape and stable identifiers.
begin
  dictionary_path = DESIGN_ROOT.join("data/data-dictionary.csv")
  dictionary = CSV.read(dictionary_path, headers: true, encoding: "UTF-8")
  expected_headers = %w[
    entity owner_module purpose tenant_key primary_key key_fields sensitivity source_of_truth rebuildable target_week
  ]
  check.call(dictionary.headers == expected_headers, "data dictionary headers differ: #{dictionary.headers.inspect}")
  entities = dictionary.map { |row| row["entity"] }
  check.call(entities.none? { |value| value.nil? || value.strip.empty? }, "data dictionary has blank entity")
  check.call(entities.uniq.length == entities.length, "data dictionary has duplicate entity")
  %w[work_order_transition outbox_event membership_role].each do |entity|
    check.call(entities.include?(entity), "data dictionary missing #{entity}")
  end
  allowed_owners = MODULES.to_set | NON_BUSINESS_OWNERS.to_set
  invalid_owners = dictionary.map { |row| row["owner_module"] }.uniq.reject { |owner| allowed_owners.include?(owner) }
  check.call(invalid_owners.empty?, "data dictionary has unknown owner modules: #{invalid_owners.join(', ')}")
rescue CSV::MalformedCSVError => e
  errors << "data/data-dictionary.csv: malformed CSV: #{e.message}"
end

begin
  permissions_path = DESIGN_ROOT.join("security/permission-matrix.csv")
  permissions = CSV.read(permissions_path, headers: true, encoding: "UTF-8")
  required_headers = %w[permission_code resource action] + ROLE_COLUMNS +
                     %w[data_scope high_risk_confirmation server_enforcement negative_test]
  check.call(permissions.headers == required_headers, "permission matrix headers differ: #{permissions.headers.inspect}")
  invalid_width_rows = []
  permissions.each_with_index do |row, index|
    invalid_width_rows << index + 2 unless row.fields.length == required_headers.length
  end
  check.call(invalid_width_rows.empty?, "permission matrix has invalid column count on rows: #{invalid_width_rows.join(', ')}")
  codes = permissions.map { |row| row["permission_code"] }
  check.call(codes.none? { |value| value.nil? || value.strip.empty? }, "permission matrix has blank code")
  check.call(codes.uniq.length == codes.length, "permission matrix has duplicate permission_code")
  allowed_values = %w[allow deny conditional].to_set
  ROLE_COLUMNS.each do |role|
    invalid = permissions.map { |row| row[role] }.uniq.reject { |value| allowed_values.include?(value) }
    check.call(invalid.empty?, "permission matrix #{role} has invalid values: #{invalid.join(', ')}")
  end
end

# Cross-document invariant names.
project_spec = PROJECT_ROOT.join("PROJECT_SPEC.md").read(encoding: "UTF-8")
design_sources = [
  read.call("README.md"), read.call("architecture.md"), read.call("data/data-model.md")
].join("\n")
MODULES.each do |name|
  check.call(project_spec.include?(name), "PROJECT_SPEC.md missing module #{name}")
  check.call(design_sources.include?(name), "design baseline missing module #{name}")
end
STATUSES.each do |status|
  check.call(project_spec.include?(status), "PROJECT_SPEC.md missing status #{status}")
  check.call(design_sources.include?(status), "design baseline missing status #{status}")
end
EVENT_FILES.each_value do |event_name|
  check.call(project_spec.include?(event_name), "PROJECT_SPEC.md missing event #{event_name}")
  check.call(read.call("events/README.md").include?(event_name), "events/README.md missing #{event_name}")
end

# Local Markdown links and fenced code blocks inside this design package.
DESIGN_ROOT.glob("**/*.md").sort.each do |path|
  source = path.read(encoding: "UTF-8")
  fence_count = source.each_line.count { |line| line.match?(/^\s*```/) }
  check.call(fence_count.even?, "#{path.relative_path_from(PROJECT_ROOT)}: unclosed fenced code block")

  source.scan(/\[[^\]]*\]\(([^)]+)\)/).flatten.each do |target|
    clean_target = target.strip
    next if clean_target.empty? || clean_target.start_with?("#", "http://", "https://", "mailto:")

    file_part = clean_target.split("#", 2).first
    linked = path.dirname.join(file_part).cleanpath
    check.call(linked.exist?, "#{path.relative_path_from(PROJECT_ROOT)}: broken link #{target}")
  end
end

if warnings.any?
  puts "\nWarnings (#{warnings.length}):"
  warnings.uniq.each { |warning| puts "  - #{warning}" }
end

if errors.empty?
  puts "\nPASS: #{checks} checks, #{EVENT_FILES.length} event schemas, 2 OpenAPI documents"
  exit 0
end

puts "\nFAIL: #{errors.length} error(s) across #{checks} checks"
errors.each { |error| puts "  - #{error}" }
exit 1
