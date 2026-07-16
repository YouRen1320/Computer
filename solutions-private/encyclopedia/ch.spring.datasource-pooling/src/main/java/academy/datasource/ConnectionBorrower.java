package academy.datasource;

import java.sql.SQLException;
import javax.sql.DataSource;

/** Proven answer: every JDBC resource is closed on success and failure paths. */
public final class ConnectionBorrower {
    private final DataSource dataSource;

    public ConnectionBorrower(DataSource dataSource) { this.dataSource = dataSource; }

    public int selectOne() throws SQLException {
        try (var connection = dataSource.getConnection();
             var statement = connection.prepareStatement("select 1");
             var result = statement.executeQuery()) {
            if (!result.next()) throw new SQLException("probe returned no row");
            return result.getInt(1);
        }
    }
}
