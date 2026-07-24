# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "tmpdir"
require_relative "../../scripts/lib/factorycare_status_contract"

class FactoryCareStatusContractTest < Minitest::Test
  def with_repository
    Dir.mktmpdir("factorycare-status-contract-") do |directory|
      yield directory
    end
  end

  def write(root, relative, body)
    path = File.join(root, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, body)
  end

  def validate(root)
    FactoryCareStatusContract.validate(root).fetch(:errors)
  end

  def test_accepts_canonical_work_order_status_subset
    with_repository do |root|
      write(root, "examples/encyclopedia/ch.demo/src/WorkOrder.java", <<~JAVA)
        final class WorkOrder {
          enum WorkOrderStatus { CREATED, IN_PROGRESS, RESOLVED, CLOSED }
          WorkOrderStatus status = WorkOrderStatus.CREATED;
        }
      JAVA

      assert_empty validate(root)
    end
  end

  def test_rejects_legacy_and_other_values_in_work_order_status_declaration
    with_repository do |root|
      write(root, "labs/encyclopedia/ch.demo/src/WorkOrder.java", <<~JAVA)
        final class WorkOrder {
          enum WorkOrderStatus { CREATED, OPEN, PAUSED }
        }
      JAVA

      errors = validate(root)
      assert_equal 1, errors.length
      assert_match(/OPEN, PAUSED/, errors.first)
    end
  end

  def test_rejects_sql_json_and_csv_legacy_status_literals
    with_repository do |root|
      write(root, "examples/encyclopedia/ch.demo/schema.sql",
            "CREATE TABLE work_order(status text);\nSELECT * FROM work_order WHERE status = 'OPEN';\n")
      write(root, "labs/encyclopedia/ch.demo/work_orders.csv", "work_order_id,status\nW-1,DONE\n")
      write(root, "exercises/encyclopedia/ch.demo/payload.json",
            "{\"kind\":\"WorkOrder\",\"status\":\"COMPLETED\"}\n")

      errors = validate(root)
      assert_equal 3, errors.length
      assert errors.any? { |error| error.include?("OPEN") }
      assert errors.any? { |error| error.include?("DONE") }
      assert errors.any? { |error| error.include?("COMPLETED") }
    end
  end

  def test_accepts_non_work_order_thread_and_sql_new_contexts
    with_repository do |root|
      write(root, "book/volume-00/chapters/thread.md",
            "工单旁注。Java Thread.State 有 NEW；这不是 WorkOrderStatus。\n")
      write(root, "examples/encyclopedia/ch.demo/operations.sql", <<~SQL)
        UPDATE work_order SET status = 'CREATED'
        RETURNING WITH (OLD AS o, NEW AS n) o.status, n.status;
      SQL

      assert_empty validate(root)
    end
  end

  def test_accepts_only_explicit_completed_ui_group_mapping
    with_repository do |root|
      write(root, "examples/encyclopedia/ch.demo/reporter-flow.mjs", <<~JS)
        // FACTORYCARE_UI_GROUP: COMPLETED <- VERIFIED|CLOSED
        // This display group is not a WorkOrderStatus.
        export function presentStatus(status) {
          return ['VERIFIED', 'CLOSED'].includes(status) ? { group: 'COMPLETED' } : { group: 'ACTIVE' }
        }
      JS

      assert_empty validate(root)

      write(root, "examples/encyclopedia/ch.demo/reporter-flow.mjs", <<~JS)
        // FACTORYCARE_UI_GROUP: COMPLETED <- VERIFIED|CLOSED
        export const order = { kind: 'WorkOrder', status: 'COMPLETED' }
      JS
      assert_match(/COMPLETED/, validate(root).join("\n"))
    end
  end

  def test_accepts_explicit_demo_ticket_projection
    with_repository do |root|
      write(root, "labs/encyclopedia/ch.demo/Demo.java", <<~JAVA)
        // FactoryCare WorkOrder uses 12 states; this is a named teaching projection.
        enum DemoTicketStatus { CREATED, ASSIGNED, IN_PROGRESS, CLOSED, CANCELLED }
      JAVA

      assert_empty validate(root)
    end
  end
end
