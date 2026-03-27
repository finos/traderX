package finos.traderx.accountservice.repository;

import finos.traderx.accountservice.model.AccountUser;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class AccountUserRepository {

  private static final RowMapper<AccountUser> ACCOUNT_USER_ROW_MAPPER = (rs, rowNum) -> {
    AccountUser accountUser = new AccountUser();
    accountUser.setAccountId(rs.getInt("AccountID"));
    accountUser.setUsername(rs.getString("Username"));
    return accountUser;
  };

  private final JdbcTemplate jdbcTemplate;

  public AccountUserRepository(JdbcTemplate jdbcTemplate) {
    this.jdbcTemplate = jdbcTemplate;
  }

  public List<AccountUser> findAll() {
    return jdbcTemplate.query(
        "select AccountID, Username from AccountUsers order by AccountID, Username",
        ACCOUNT_USER_ROW_MAPPER
    );
  }

  public Optional<AccountUser> findByAccountId(int accountId) {
    List<AccountUser> rows = jdbcTemplate.query(
        "select AccountID, Username from AccountUsers where AccountID = ? order by Username",
        ACCOUNT_USER_ROW_MAPPER,
        accountId
    );
    return rows.stream().findFirst();
  }

  public boolean exists(int accountId, String username) {
    Integer count = jdbcTemplate.queryForObject(
        "select count(*) from AccountUsers where AccountID = ? and Username = ?",
        Integer.class,
        accountId,
        username
    );
    return count != null && count > 0;
  }

  public AccountUser save(AccountUser accountUser) {
    if (!exists(accountUser.getAccountId(), accountUser.getUsername())) {
      jdbcTemplate.update(
          "insert into AccountUsers (AccountID, Username) values (?, ?)",
          accountUser.getAccountId(),
          accountUser.getUsername()
      );
    }
    return accountUser;
  }
}
