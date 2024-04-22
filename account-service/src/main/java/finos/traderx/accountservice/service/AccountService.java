package finos.traderx.accountservice.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import finos.traderx.accountservice.exceptions.ResourceNotFoundException;
import finos.traderx.accountservice.model.Account;
import finos.traderx.accountservice.repository.AccountRepository;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

@Service
public class AccountService {

	@Autowired
	AccountRepository accountRepository;

	public List<Account> getAllAccount() {
		List<Account> accounts = new ArrayList<>();
		this.accountRepository.findAll().forEach(account -> accounts.add(account));
		return accounts;
	}

	public Account getAccountById(int id) throws ResourceNotFoundException {
		Optional<Account> account = this.accountRepository.findById(id);
		if (account.isEmpty()) {
			throw new ResourceNotFoundException("Account with id " + id + "not found");
		}
		return account.get();
	}

	public Account upsertAccount(Account account) {
		return this.accountRepository.save(account);
	}
}
