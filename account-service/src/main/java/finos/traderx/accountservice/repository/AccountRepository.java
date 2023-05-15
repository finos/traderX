package finos.traderx.accountservice.repository;

import finos.traderx.accountservice.model.Account;

import org.springframework.data.repository.CrudRepository;

public interface AccountRepository extends CrudRepository<Account, Integer> {
}
