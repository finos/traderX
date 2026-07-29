package finos.traderx.accountservice.service;

import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.Account;
import finos.traderx.accountservice.repository.AccountRepository;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class AccountService {

  private final AccountRepository accountRepository;

  public AccountService(AccountRepository accountRepository) {
    this.accountRepository = accountRepository;
  }

  public List<Account> getAllAccount() {
    return accountRepository.findAll();
  }

  public Account getAccountById(int id) {
    return accountRepository.findById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Account with id " + id + " not found"));
  }

  public Account upsertAccount(Account account) {
    return accountRepository.save(account);
  }
}
