package finos.traderx.accountservice.repository;

import finos.traderx.accountservice.model.AccountUser;

import finos.traderx.accountservice.model.AccountUserID;
import java.util.Optional;
import org.springframework.data.repository.CrudRepository;

public interface AccountUserRepository extends CrudRepository<AccountUser, AccountUserID> {

  // since the primary key includes the username, this could return a collection.
  // To fix this requires also changing the service and controller
  Optional<AccountUser> findByAccountId(Integer accountId);
}
