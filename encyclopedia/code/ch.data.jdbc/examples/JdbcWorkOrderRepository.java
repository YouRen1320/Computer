import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import javax.sql.DataSource;

// Direct JDBC teaching example: owns SQL, mapping, resources, and transaction boundaries.
public final class JdbcWorkOrderRepository {
    private static final String FIND_BY_ID = """
            SELECT work_order_id, status, assigned_to, created_at, version
            FROM factorycare.work_order
            WHERE work_order_id = ?
            """;

    private static final String FIND_BY_STATUS = """
            SELECT work_order_id, status, assigned_to, created_at, version
            FROM factorycare.work_order
            WHERE status = ?
            ORDER BY work_order_id
            """;

    private final DataSource dataSource;

    public JdbcWorkOrderRepository(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public Optional<WorkOrderRow> findById(long id) throws SQLException {
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(FIND_BY_ID)) {
            statement.setLong(1, id);
            try (ResultSet result = statement.executeQuery()) {
                if (!result.next()) {
                    return Optional.empty();
                }
                WorkOrderRow row = mapRow(result);
                if (result.next()) {
                    throw new SQLException("work_order_id returned multiple rows");
                }
                return Optional.of(row);
            }
        }
    }

    public List<WorkOrderRow> findByStatus(String status) throws SQLException {
        try (Connection connection = dataSource.getConnection();
             PreparedStatement statement = connection.prepareStatement(FIND_BY_STATUS)) {
            statement.setString(1, status);
            try (ResultSet result = statement.executeQuery()) {
                List<WorkOrderRow> rows = new ArrayList<>();
                while (result.next()) {
                    rows.add(mapRow(result));
                }
                return List.copyOf(rows);
            }
        }
    }

    public void assign(AssignCommand command) throws SQLException {
        try (Connection connection = dataSource.getConnection()) {
            connection.setAutoCommit(false);
            try {
                int changed = updateWorkOrder(connection, command);
                if (changed != 1) {
                    throw new SQLException("expected one changed row, actual=" + changed);
                }
                insertHistory(connection, command);
                connection.commit();
            } catch (SQLException failure) {
                try {
                    connection.rollback();
                } catch (SQLException rollbackFailure) {
                    failure.addSuppressed(rollbackFailure);
                }
                throw failure;
            }
        }
    }

    private int updateWorkOrder(Connection connection, AssignCommand command) throws SQLException {
        String sql = """
                UPDATE factorycare.work_order
                SET status = ?, assigned_to = ?, version = version + 1
                WHERE work_order_id = ? AND version = ?
                """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setString(1, "IN_PROGRESS");
            statement.setLong(2, command.assignedTo());
            statement.setLong(3, command.workOrderId());
            statement.setLong(4, command.expectedVersion());
            return statement.executeUpdate();
        }
    }

    private void insertHistory(Connection connection, AssignCommand command) throws SQLException {
        String sql = """
                INSERT INTO factorycare.work_order_history
                  (command_id, work_order_id, to_status, assigned_to)
                VALUES (?, ?, ?, ?)
                """;
        try (PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setObject(1, command.commandId());
            statement.setLong(2, command.workOrderId());
            statement.setString(3, "IN_PROGRESS");
            statement.setLong(4, command.assignedTo());
            statement.executeUpdate();
        }
    }

    private static WorkOrderRow mapRow(ResultSet result) throws SQLException {
        return new WorkOrderRow(
                result.getLong("work_order_id"),
                result.getString("status"),
                result.getObject("assigned_to", Long.class),
                result.getObject("created_at", OffsetDateTime.class),
                result.getLong("version"));
    }

    public record WorkOrderRow(long id, String status, Long assignedTo,
                               OffsetDateTime createdAt, long version) {}

    public record AssignCommand(java.util.UUID commandId, long workOrderId,
                                long assignedTo, long expectedVersion) {}
}
