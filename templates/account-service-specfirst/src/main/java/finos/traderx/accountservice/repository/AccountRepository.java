package finos.traderx.accountservice.repository;

import finos.traderx.accountservice.model.Account;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class AccountRepository {

  private static final RowMapper<Account> ACCOUNT_ROW_MAPPER = (rs, rowNum) -> {
    Account account = new Account();
    account.setId(rs.getInt("ID"));
    account.setDisplayName(rs.getString("DisplayName"));
    return account;
  };

  private final JdbcTemplate jdbcTemplate;

  public AccountRepository(JdbcTemplate jdbcTemplate) {
    this.jdbcTemplate = jdbcTemplate;
  }

  public List<Account> findAll() {
    return jdbcTemplate.query(
        "select ID, DisplayName from Accounts order by ID",
        ACCOUNT_ROW_MAPPER
    );
  }

  public Optional<Account> findById(int id) {
    List<Account> rows = jdbcTemplate.query(
        "select ID, DisplayName from Accounts where ID = ?",
        ACCOUNT_ROW_MAPPER,
        id
    );
    return rows.stream().findFirst();
  }

  public Account save(Account account) {
    Integer accountId = account.getId();
    if (accountId == null || accountId <= 0) {
      Integer generatedId = jdbcTemplate.queryForObject("select next value for ACCOUNTS_SEQ", Integer.class);
      jdbcTemplate.update("insert into Accounts (ID, DisplayName) values (?, ?)", generatedId, account.getDisplayName());
      account.setId(generatedId);
      return account;
    }

    int updated = jdbcTemplate.update(
        "update Accounts set DisplayName = ? where ID = ?",
        account.getDisplayName(),
        accountId
    );

    if (updated == 0) {
      jdbcTemplate.update("insert into Accounts (ID, DisplayName) values (?, ?)", accountId, account.getDisplayName());
    }

    return account;
  }

  public boolean existsById(int id) {
    Integer count = jdbcTemplate.queryForObject(
        "select count(*) from Accounts where ID = ?",
        Integer.class,
        id
    );
    return count != null && count > 0;
  }
}
