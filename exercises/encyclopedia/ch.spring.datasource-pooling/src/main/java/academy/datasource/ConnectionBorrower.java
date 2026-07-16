package academy.datasource;

import java.sql.SQLException;
import javax.sql.DataSource;

/** Starter defect: the borrower never returns its connection to the pool. */
public final class ConnectionBorrower {
    private final DataSource dataSource;

    public ConnectionBorrower(DataSource dataSource) { this.dataSource = dataSource; }

    public int selectOne() throws SQLException {
        var connection = dataSource.getConnection();
        var statement = connection.prepareStatement("select 1");
        var result = statement.executeQuery();
        result.next();
        return result.getInt(1);
    }
}
